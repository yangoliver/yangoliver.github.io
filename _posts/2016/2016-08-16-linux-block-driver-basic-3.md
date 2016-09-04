---
layout: post
title: Linux Block Driver - 3
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

>转载时请包含原文或者作者网站链接：<http://oliveryang.net>

* content
{:toc}

## 1. 背景

在 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2/) 中，我们在 Sampleblk 驱动创建了 Ext4 文件系统，并做了一个简单的 fio 测试。

本文将继续之前的实验，围绕这个简单的 fio 测试，探究 Linux 块设备驱动和文件 IO 的运作机制。除非特别指明，本文中所有 Linux 内核源码引用都基于 4.6.0。其它内核版本可能会有较大差异。
若需对 Sampleblk 块驱动实现有所了解，请参考 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)。

## 2. 准备

阅读本文前，可能需要如下准备工作，

- 了解 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2/) 中所提的 fio 测试的环境准备，命令运行，还有性能分析方法。
- 了解 [Flamegraph](https://github.com/brendangregg/FlameGraph) 如何解读。

在上篇文章中，通过使用 [Flamegraph](https://github.com/brendangregg/FlameGraph)，我们把 fio 测试中做的 perf profiling 的结果可视化，生成了如下火焰图,

<img src="/media/images/2016/flamegraph_on_cpu_perf_fs_seq_write_sync_001.svg" width="100%" height="100%" />

在新窗口中打开图片，我们可以看到，火焰图不但可以帮助我们理解 CPU 全局资源的占用情况，而且还能进一步分析到微观和细节。例如局部的热锁，父子函数的调用关系，和所占 CPU 时间比例。
关于进一步的 Flamegraph 的介绍和资料，请参考 [Brenden Gregg 的 Flamegraph 相关资源](http://www.brendangregg.com/flamegraphs.html)。

本文中，该火焰图将成为我们粗略了解该 fio 测试在 Linux 4.6.0 内核涉及到的文件 IO 内部实现的主要工具。

## 3. 深入理解文件 IO

在上一篇文章中，我们发现，尽管测试的主要时间都发生在 `write` 系统调用上。但如果查看单次系统调用的时间，`fadvise64` 远远超过了 `write`。
为什么 `write` 和 `fadvise64` 调用的执行时间差异如此之大？如果对 Linux buffer IO 机制，文件系统 page cache 的工作原理有基本概念的话，这个问题并不难理解，

- Page cache 加速了文件读写操作

  一般而言，`write` 系统调用虽然是同步 IO，但 IO 数据是写入 page cache 就立即返回的，因此实际开销是写内存操作，而且只写入 page cache 里，不会对块设备发起 IO 操作。
  应用如果需要保证数据写到磁盘上，必需在 `write` 调用之后调用 `fsync` 来保证文件数据在 `fsync` 返回前把数据从 page cache 甚至硬盘的 cache 写入到磁盘介质。

- Flush page cache 会带来额外的开销

  虽然 page cache 加速了文件系统的读写操作，但一旦需要 flush page cache，将集中产生大量的磁盘 IO 操作。磁盘 IO 操作比写 page cache 要慢很多。因此，flush page cache 非常费时而且影响性能。

由于 Linux 内核提供了强大的动态追踪 (Dynamic Trace) 能力，现在我们可以通过内核的 trace 工具来了解 `write` 和 `fadvise64` 调用的执行时间差异。

### 3.1 使用 Ftrace

Linux `strace` 只能追踪系统调用界面这层的信息。要追踪系统调用内部的机制，就需要借助 Linux 内核的 trace 工具了。Ftrace 就是非常简单易用的追踪系统调用内部实现的工具。

不过，Ftrace 的 UI 是基于 linux debugfs 的。操作起来有些繁琐。
因此，我们用 Brendan Gregg 写的 [funcgraph](https://github.com/brendangregg/perf-tools/blob/master/examples/funcgraph_example.txt) 来简化我们对 Ftrace 的使用。
这个工具是基于 Ftrace 的用 bash 和 awk 写的脚本，非常容易理解和使用。
关于 Brendan Gregg 的 perf-tools 的使用，请阅读 [Ftrace: The hidden light switch](http://lwn.net/Articles/608497) 这篇文章。
此外，Linux 源码树里的 [Documentation/trace/ftrace.txt](https://github.com/torvalds/linux/blob/master/Documentation/trace/ftrace.txt) 就是极好的 Ftrace 入门材料。

### 3.2 open

运行 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2/) 中的 fio 测试时，用 `funcgraph` 可以获取 `open` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_open

详细的 `open` 系统调用函数图日志可以查看 [这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_open_fs_seq_write_sync_001.log)。

仔细察看函数图日志就会发现，`open` 系统调用打开普通文件时，并没有调用块设备驱动的代码，而只涉及到下面两个层次的处理，

1. VFS 层。

   VFS 层的 `open` 系统调用代码为进程分配 fd，根据文件名查找元数据，为文件分配和初始化 `struct file`。在这一层的元数据查找、读取，以及文件的打开都会调用到底层具体文件系统的回调函数协助完成。
   最后在系统调用返回前，把 fd，和 `struct file` 装配到进程的 `struct task_struct` 上。

   要强调的是，`struct file` 是文件 IO 中最核心的数据结构之一，其内部包含了如下关键信息，

   * 文件路径结构。即 `f_path` 成员，其类型为 `struct path`。

     内核可以直接得到 `vfsmount` 和 `dentry`，即可唯一确定一个文件的位置。

     这个 `vfsmount` 和 `dentry` 的初始化由 `do_last` 函数来搞定。如果文件以 `O_CREAT` 方式打开，则最终调用 `lookup_open` 来搞定。若无 `O_CREAT` 标志，则由 `lookup_fast` 来搞定。
     最终，`dentry` 要么已经有对应的 `inode`，这时 `dentry` 要么在 dentry cache 里，要么需要调用 `lookup` 方法 (Ext4 对应的 `ext4_lookup` 方法) 从磁盘上读取出来。
     还有一种情况，即文件是 `O_CREAT` 方式打开，文件虽然不存在，也会由 `lookup_open` 调用 `vfs_create` 来为这个 `dentry` 创建对应的 `inode`。
     而文件创建则需要借助具体文件系统的 `create` 方法，对 Ext4 来说，就是 `ext4_create`。

   * 文件操作表结构。即 `f_op` 成员，其类型为 `struct file_operations`。

     文件 IO 相关的方法都定义在该结构里。文件系统通过实现该方法来完成对文件 IO 的具体支持。

     当 `vfsmount` 和 `dentry` 都被正确得到后，就会通过 `vfs_open` 调用 `do_dentry_open` 来初始化文件操作表。
	 最终，实际上 `struct file` 的 `f_op` 成员来自于其对应 `dentry` 的对应 `inode` 的 `i_fop` 成员。
	 而我们知道，`inode` 都是调用具体文件系统的方法来分配的。例如，对 Ext4 来说，`f_op` 成员最终被 `ext4_lookup` 或 `ext4_create` 初始化成了 `ext4_file_operations`。

   * 文件地址空间结构。即 `f_mapping` 成员，其类型为 `struct address_space`。

     地址空间结构内部包括了文件内存映射的内存页面，和其对应的地址空间操作表 `a_ops` (类型为 `struct address_space_operations`)，都在其中。

     与 `f_op` 成员类似，`f_mapping` 成员也通过 `vfs_open` 调用 `do_dentry_open` 来初始化。而地址空间结构内部的地址空间操作表，也是通过具体文件系统初始化的。
     例如，Ext4 上，该地址空间操作表被 `ext4_lookup` 或 `ext4_create` 初始化为 `ext4_da_aops`。

   当 `open` 调用返回时，用户程序通过 `fd` 就可以让内核在文件操作时访问到对应的 `struct file`，从而可以定位到具体文件，做相关的 IO 操作了。

   在 open 结束时，在 `vfs_open` 实现里检查是否实现了 `open` 方法，若实现就调用到具体文件系统的 `open` 方法。例如，Ext4 文件系统的 `ext4_file_open` 方法。
   很多文件系统根本不会实现自己的 `open` 方法，这时就不悔调用 `open` 方法。或者，一些文件系统将该方法初始化为 `generic_file_open`。
   现在的 `ext4_file_open` 函数最终会在返回前调用 VFS 层的 `generic_file_open`。
   而 `generic_file_open` 只检查是否在 32 位系统上打开大文件而导致 overflow 的情况，在 64 位系统上，`generic_file_open` 相当于空函数。

2. 具体文件系统层。

   以 Ext4 为例，Ext4 注册在 VFS 层的入口函数被上层调用，为上层查找元数据 (`ext4_lookup`)，创建文件 (`ext4_create`)，打开文件 (`ext4_file_open`) 提供服务。

   * 当 dentry cache 里查找不到对应文件的 `dentry` 结构时，需要从磁盘上查找。这时调用 `ext4_lookup` 方法来查找。

   * 当文件不再磁盘上，因为 `O_CREAT` 标志被设置，需要创建文件时，调用 `ext4_create` 创建文件。

   * 当文件被定位后，最终调用 `f_op` 成员的 `open` 方法，即 `ext4_file_open`。

   本例中的 `fio` 测试里，由于文件已经被创建，而且元数据已经缓存在内存中，因此，只涉及到 `ext4_file_open` 的代码。
   早期 Ext4 代码并未实现自己独特的 `open` 方法。
   后来 [Ext4 为了管理员提供了记录上次 mount 点的功能，引入了自己的 `ext4_file_open` 函数](https://github.com/torvalds/linux/commit/bc0b0d6d69ee9022f18ae264e62beb30ddeb322a)。
   而 `ext4_file_open` 逐渐也加入了其它边缘功能。该函数最终会在返回前调用 VFS 层的 `generic_file_open`。

### 3.3 fadvise64

用 `funcgraph` 也可以获取 `fadvise64` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_fadvise64

详细的 `fadvise64` 系统调用的跟踪日志请查看[这里](https://raw.githubusercontent.com/yangoliver/lktm/master/drivers/block/sampleblk/labs/lab1/funcgraph_fadvise_fs_seq_write_sync_001.log)。

根据 [fadvise64(2)](http://linux.die.net/man/2/fadvise64)，这个系统调用的作用是预先声明文件数据的访问模式。

从前面 `strace` 的日志里我们得知，每次 `open` 文件之后，`fio` 都会调用两次 `fadvise64` 系统调用，只不过两次的 `advise` 参数使用有所差别，因而起到的作用也不同。
下面就对本实验中涉及到的两个 `advise` 参数做简单介绍。

#### 3.3.1 POSIX_FADV_SEQUENTIAL

POSIX_FADV_SEQUENTIAL 主要是应用用来通知内核，它打算以顺序的方式去访问文件数据。

如果参考我们获得的 `fadvise64` 系统调用的函数图，再结合源码，我们知道，POSIX_FADV_SEQUENTIAL 的实现非常简单，主要有以下两方面，

1. 把 VFS 层文件的预读窗口增大到默认的两倍。
2. 把文件对应的内核结构 `struct file` 的文件模式 `file->f_mode` 的随机访问 `FMODE_RANDOM` 标志位清除掉。从而让 VFS 预读算法对顺序读更高效。

由于以上操作仅仅涉及简单内存访问操作，因此在 `fadvise64` 系统调用的函数图里，我们可以看到它仅仅用了 0.891 us 就返回了，远远快于另外一个命令。

综上所述，POSIX_FADV_SEQUENTIAL 操作的代码路径下，全都是对文件系统预读的优化。而本文中的 `fio` 测试只有顺序写操作，因此，POS IX_FADV_SEQUENTIAL 的操作对本测试没有任何影响。

#### 3.3.2 POSIX_FADV_DONTNEED

POSIX_FADV_DONTNEED 则是应用通知内核，与文件描述符 `fd` 关联的文件的指定范围 (`offset` 和 `len` 描述)的 page cache 都不需要了，脏页可以刷到盘上，然后直接丢弃了。

Linux 提供了全局刷 page cache 到磁盘，然后丢弃 page cache 的接口: /proc/sys/vm/drop_pagecache。然而 `fadvise64` 的 POSIX_FADV_DONTNEED 作用域是文件内的某段范围，具有更细的粒度。

在我们 `fadvise64` 系统调用的跟踪日志里，调用图关系最复杂，返回时间最长的就是这个命令了。
但如果参考其源码实现，其实该命令主要分为两大步骤，

1. 回写 (Write Back) 页缓存。
2. 清除 (Invalidate) 页缓存。

##### 3.3.2.1 回写页缓存

回写 (Write Back) 文件内部指定范围的 dirty page cache 到磁盘。

首先，检查是否符合回写的触发条件，然后调用 `__filemap_fdatawrite_range` 对文件指定范围回写。
如果文件 inode 回写拥塞位被置位的话，则跳过回写操作。这时，`fadvise64` 系统调用还会在第 2 步时，尽量清除回收文件所属的 Page Cache。
这个回写拥塞控制是 [Cgroup Write Back](http://events.linuxfoundation.org/sites/events/files/slides/2015-LCJ-cgroup-writeback.pdf) 特性的一部分。

如果可以回写，调用 `__filemap_fdatawrite_range`。 该函数支持时以下两种同步写模式，

* `WB_SYNC_ALL` 指示代码在回写页面时，遇到某个页已经正在被别人回写时，睡眠等待。这样可以保证数据的完整性。因此 `fsync` 或者 `msync` 这类调用必须使用这个同步模式。
* `WB_SYNC_NONE` 指示代码遇到某个页被别人回写时，跳过该页而避免等待。这种方式通常只用于内存回收的时候。

不论设置为上述哪种方式，页面回写都是同步的。也就是说，当磁盘 IO 结束返回之前，回写会等待。两者的差别仅仅是当有页面正在其它 IO 上下文时，是否要跳过。

POSIX_FADV_DONTNEED 的主要目的是清除 page cache，因此它使用了 WB_SYNC_NONE。

完整的脏页回写过程经历了以下 5 个层次，

1. **VFS 层**

   如前所述，`fadvise64` 系统调用使用的 `__filemap_fdatawrite_range`， 是 VFS 层的函数。
   VFS 层最终会使用 MM 子系统提供的页缓存回写函数 `do_writepages` 来完成回写。

2. **MM 子系统**

   函数 `do_writepages` 最终会根据文件系统是否对该地址空间 `struct address_space` 的 `a_ops` 操作表是否初始化了 `writepages` 成员来决定页回写的处理。
   主要有以下两种情况，

   - 未初始化 `writepages` 成员。
     这时由 MM 子系统的 `generic_writepages` 调用 `write_cache_pages` 来遍历文件地址空间内的脏页，并最终调用具体文件系统的 `writepage` 回调来对每一个页做写 IO。

   - 初始化了 `writepages` 成员。
	 由于具体文件系统模块已经初始化了 `writepages` 成员，则页缓存回写由具体文件系统的 `writepages` 的回调来直接处理。

   本文实验环境中，属于第二种情况，即 `writepages` 成员已经被 Ext4 初始化。

3. **具体文件系统层**

   本实验里使用的 Ext4 文件系统在 `struct address_space_operations` 里已经把 `writepages` 初始化为 `ext4_writepages`。因此，回写缓存的处理会由该函数来完成。

   函数 `ext4_writepages` 处理页缓存回写的要点如下，

   - 当 Ext4 文件系统以 `data=journal` 方式 mount 时

     在函数一开始就检查，如果是 `data=journal` 方式，使用 MM 子系统的 `write_cache_pages` 来做页缓存的 page cache 处理。
     这条代码路径的实际效果和文件系统不实现 `writepages` 成员的处理是一样的。最终 `write_cache_pages` 还会使用 Ext4 的另一个 `writepage` 回调，即 `ext4_writepage` 来对单个脏页做 IO 操作。
	 实际上，在早期的内核版本，Ext4 会根据 mount 是否支持或者使用了 [delalloc ((Delay Allocation)](https://github.com/torvalds/linux/blob/master/Documentation/filesystems/ext4.txt#L266) 特性，
	 来决定使用不同的 `struct address_space_operations` 的操作表声明。根据 mount 模式是否支持 **delalloc 特性**，Ext4 的缓存回写使用了不同的入口函数。
	 关闭 Delay Allocation 特性时，不初始化 `writepages`，就都使用 `write_cache_pages`。

     但 Linux 3.11 版本开始 [Ext4 使用统一的 `ext4_writepages` 入口函数处理缓存回写](https://github.com/torvalds/linux/commit/20970ba65d5a22f2e4efbfa100377722fde56935)。
     这个改动使得 `data=ordered` 模式下，即使 Delay Allocation 特性是**关闭**的，也会使用 `ext4_writepages` 方式，而不使用 `write_cache_pages` 方式。

   - 当 Ext4 使用非 `data=journal` 方式 mount 时

     例如 `data=ordered` 或 `data=writeback`。本文中就是 Ext4 缺省模式，`data=ordered`。

     * 调用 `mpage_prepare_extent_to_map`。找到连续的还未在磁盘上建立块映射的脏页，把它们加入 `extent` 并调用 `mpage_map_and_submit_extent` 来映射和提交这些脏页。
	   如果脏页已经在磁盘上有块影射了，则直接提交这些页面。两种情况最终都会调用 `ext4_bio_write_page` 将要提交 IO 的页面加入到 `struct ext4_io_submit` 成员 `io_bio` 的 `bio` 结构里。

     * 通过 `ext4_io_submit` 调用 `submit_bio`，从而把之前提交到 `struct ext4_io_submit` 成员 `io_bio` 里的 `bio` 结构提交给通用块层。

    篇幅有限，这里不再对 delalloc 特性做更详细的解读。

4. **通用块层**

   Ext4 的 `ext4_writepages` 使用了以下通用块层的机制或接口，

   - Plug (蓄水) 机制。
     对应函数为 `blk_start_plug`，会在提交 IO 请求之前，在当前进程的 `task_struct` 里初始化一个列表，用于通用块层的 IO 请求排队。
     随后通过 `submit_bio` 提交给通用块层的 `bio` 请求，都在通用块层排队，而不立刻下发给更低层的块驱动。这个过程被叫做 Plug (蓄水)。

   - `submit_bio` 接口。
     在调用 `submit_bio` 提交 `bio` 给通用块层之后，通用块层会调用 `generic_make_request`。在此函数内，通过调用 `blk_queue_bio` 根据 `bio` 来构造 IO `request`，
     把或者将 `bio` 合并到一个已经存在的 `request` 里。这时的 `request` 可以在当前任务的 `plug` 列表里，或在块设备的 `request_queue` 队列里。
     当新提交的 `bio` 被构造或者合并入一个 IO `request` 以后，这些 `request` 并不是立刻被发送给下层的块驱动程序，而是在 `plug` 列表或者 `request_queue` 里缓存，`submit_bio` 会直接返回。

   - Unplug (排水) 机制。
     对应函数为 `blk_finish_plug` 或 `blk_flush_plug_list`，该函数调用 `__blk_run_queue` 将所有 IO 请求都交给块驱动程序发送。
	 Unplug 机制在以下两个时机会被触发，
     * 在通用块层，如果 `blk_queue_bio` 发现当前任务的 `plug` 列表里蓄积了足够多的 IO `request`，这时通用块层会主动触发 Unplug 机制，调用块驱动程序做真正的 IO 操作。
     * Ext4 文件系统在完成所有回写操作后，主动触发 Unplug 操作。

5. **具体块驱动**。

   最终，通用块驱动的策略函数被调用来发送 IO 请求。在 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中，
   我们知道，本实验中的 Sampleblk 块驱动的策略函数为 `sampleblk_request`。这个函数的实现在那篇文章里有详细的讲解。

上述 5 个层次中提到的函数名称都可以在前面提到的 `fadvise64`
[函数图的日志](https://raw.githubusercontent.com/yangoliver/lktm/master/drivers/block/sampleblk/labs/lab1/funcgraph_fadvise_fs_seq_write_sync_001.log)
里找到。由于内部调用关系很复杂，另一个直观和简单的方式就是查看前面章节中保存的[火焰图](http://oliveryang.net/media/images/2016/flamegraph_on_cpu_perf_fs_seq_write_sync_001.svg)。

##### 3.3.2.2 清除页缓存

将文件对应的指定范围的 page cache **尽可能**清除 (Invalidate)。**尽可能**，就意味着这个清除操作可能会跳过一些页面，例如，跳过已经被加锁的页面，从而避免因等待 IO 完成而阻塞。
其主要过程如下，

- 利用 `pagevec_lookup_entries` 对范围内的每个页面调用 `invalidate_inode_page` 操作清除缓存页面。在此之前，使用 `trylock_page` 来尝试锁页。如果该页已经被锁住，则跳过该页，从而避免阻塞。
  由于 Ext4 为每一个属于 page cache 的页面创建了与之关联的 meta data, 因此这个过程中还需要调用 `releasepage` 回调，即 `ext4_releasepage` 来进行释放。
- 调用 `pagevec_release` 减少这些页面的引用计数。如果之前的清除操作成功，此时页面引用计数为 0，会将页面从 LRU 链表拿下，并释放页面。释放后的页面被归还到 per zone 的 Buddy 分配器的 free 链表里。

### 3.4 write

用 `funcgraph` 也可以获取 `write` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_write

详细的 `write` 系统调用的跟踪日志请查看[这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_write_fs_seq_write_sync_001.log)。

由于我们的测试是 buffer IO，因此，`write` 系统调用只会将数据写在文件系统的 page cache 里，而不会写到 Sampleblk 的块设备上。
系统调用 `write` 过程会经过以下层次，

1. VFS 层。

   内核的 `sys_write` 系统调用会直接调用 `vfs_write` 进入到 VFS 层代码。
   VFS 层为每个文件系统都抽象了文件操作表 `struct file_operations`。如果 `write` 回调被底层文件系统模块初始化了，就优先调用 `write`。否则，就调用 `write_iter`。

   这里不得不说，基于 iov_iter 的接口正在成为 Linux 内核处理用户态和内核态 buffer 传递的标准。而 `write_iter` 就是基于 `iov_iter` 的新的文件写 IO 的标准入口。
   Linux 内核 IO 和网络栈的各种与用户态 buffer 打交道的接口都在被 `iov_iter` 的新接口所取代。进一步讨论请阅读 [The iov_iter interface](https://lwn.net/Articles/625077/)。

   此外，Linux 4.1 中，[原有的 `aio_read` 和 `aio_write` 也都被删除](https://github.com/torvalds/linux/commit/8436318205b9f29e45db88850ec60e326327e241)，
   取而代之的正是 `read_iter` 和 `write_iter`。其中 `write_iter` 相关的要点如下，

   - `write_iter` 既支持同步 (sync) IO，又支持异步 (async) IO。
   - Linux 内核的同步 IO，即 `sys_write` 系统调用，最终通过 `new_sync_write` 来调用 `write_iter`。
   - `new_sync_write` 是通过调用 `init_sync_kiocb` 来调用 `write_iter` 的。这使得底层文件系统可以通过 `is_sync_kiocb` 来判断当前发起的 IO 是同步还是异步。
     而 `is_sync_kiocb` 主要判断依据是 `struct kiocb` 的 `ki_complete` 的取值为 NULL，即没有设置完成回调。
   - Linux 内核的异步 IO，则通过 `sys_io_submit` 系统调用来调用 `write_iter`。而此时异步 IO 恰恰设置了 `ki_complete` 的回调为 `aio_complete`。

2. 具体文件系统和 MM 子系统

   Linux 4.1 之后，文件系统在声明文件操作表 `struct file_operations` 时，若要支持读写，可以不实现标准的 `read` 和 `write`，但一定要实现 `read_iter` 和 `write_iter`。
   本文中的 Ext4 文件系统，只实现了 `write_iter` 入口｀，即 `ext4_file_write_iter`。
   对一些特殊情况做处理之后，MM 子系统的 入口函数 `__generic_file_write_iter` 被调用。在 MM 子系统的处理逻辑里，主要有以下两大分支，

   - Direct IO。
     如果文件打开方式为 O_DIRECT，这时 `kiocb` 的 `ki_flags` 被设置为 IOCB_DIRECT。此标志作为 Direct IO 模式检查的依据。
     而 MM 子系统的 `generic_file_direct_write` 会再次调用文件系统的地址空间操作表的 `direct_IO` 方法，在 Ext4 里就是 `ext4_direct_IO`。

     在 Direct IO 上下文，文件系统可以通过 `is_sync_kiocb` 来判断是否是同步 IO 或异步 IO，然后进入到具体的处理逻辑。
     本文中的实验，fio 使用的是 Buffer IO，因此这部分不进行详细讨论。

   - Buffer IO。
     使用 Buffer IO 的时候，文件系统的数据都会写入到文件系统的 page cache 后立即返回。这也是本文中测试实验的情况。
     MM 子系统的 `generic_perform_write` 方法会做如下处理，

     * 调用文件系统的 `write_begin` 方法。Ext4 就是 `ext4_da_write_begin`。
       此函数通过调用 `grab_cache_page_write_begiin` 来分配新的 page cache。然后调用 `ext4_map_blocks` 在磁盘上分配新的，或者映射已存在的 block。
     * 调用 `iov_iter_copy_from_user_atomic` 把 `sys_write` 系统调用用户态 buffer 里的数据拷贝到 `write_begin` 方法返回的页面。
     * 调用文件系统的 `write_end` 方法，即 `ext4_da_write_end`。该函数最终会将写完的 `buffer_head` 标记为 dirty。

### 3.5 close

用 `funcgraph` 也可以获取 `close` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_close

详细的 `close` 系统调用的跟踪日志请查看[这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_close_fs_seq_write_sync_001.log)。

`close` 系统调用主要分两个阶段，

- 系统调用部分。首先，由 `close` 系统调用的参数 `fd`，可以得到其对应的 `struct file` 结构。而该结构里定义了该文件的文件操作表。
  如果文件系统实现了该文件操作表的 `flush` 方法，则调用该方法，保证所有与该文件相关的 pending operations 都可以在 `close` 调用返回前结束。
  最后通过 `schedule_delayed_work` 来让内核延迟执行 `delayed_fput` 处理函数。

  需要指出的是，这种关闭时自动执行的 `flush` 方法不是必须的，很多文件系统，例如 Ext4 并不支持该方法。事实上，应用程序通常是主动调用 `fsync` 系统调用，从而调用文件系统的 `fsync` 方法来保证数据落盘。

- 延迟执行部分。为防止死锁等不可预期情况发生，保证 `fput` 操作可以被安全的执行，内核实现了 [delay fput 的机制](https://lwn.net/Articles/494158/)。
  该机制利用了 `task_work_add` 机制，保证延迟执行的 `fput` 操作可以在 `close` 系统调用返回到用户进程代码执行前，先被执行和立即返回。
  真正的 `fput` 实现会调用文件操作表的 `fasync` 和 `release` 方法，来实现文件系统层面上所需要的处理。
  最后，`struct file` 结构会被彻底释放掉。

  Linux 3.6 开始，[fput 的实现开始迁移到 `task_work_add` 之上](https://github.com/torvalds/linux/commit/4a9d4b024a3102fc083c925c242d98ac27b1c5f6)。
  而这个机制和一般异步执行机制如 work queue 最大的区别在于，该机制保证延迟执行的函数会在用户进程从系统调用代码返回到用户空间时被同步的执行。
  这样可以保证 `close` 语义不会被改变，其所有内核操作都会在用户进程取得控制权前被完成。

  以 Ext4 为例，它并没有实现 `fasync` 方法，但却实现了 `release` 方法，即 `ext4_release_file`。
  该方法与 `open` 方法不同的是，`open` 方法每次打开文件都必须被调用，但 `release` 方法只有在最后一个关闭文件的操作执行时被调用。
  此时，当文件系统以 `auto_da_alloc` 为 mount option 时，`ext4_release_file` 会调用 `filemap_flush` 来保证在 `close` 前，延迟分配的块可以被写入到磁盘。
  关于[`auto_da_alloc` 的目的和意义](https://github.com/torvalds/linux/blob/master/Documentation/filesystems/ext4.txt#L312)，请阅读相关内核文档。

## 4. 实验

运行 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2/) 中的 fio 那个测试时，我们也可以利用 Linux Crash 工具来检查文件 IO 涉及的关键数据结构。
Redhat 自带的 Crash 版本无法支持 4.6.0 内核，为此，您可能需要参考 [Linux Crash - coding notes](http://oliveryang.net/2015/07/linux-crash-coding-notes/) 最后一小节，重新编译新版 crash。

按照如下步骤，即可在运行 `fio` 时，以只读方式查看内核数据结构，

- 进入 crash，以只读方式查看内核。

	  $ sudo ./crash

- 用 `foreach files` 查看哪些进程打开了 /mnt/test 文件。可以看到，两个 `fio` 任务分别各自打开了该文件，

	  crash> foreach files -R /mnt/test
	  PID: 19670  TASK: ffff8800000715c0  CPU: 1   COMMAND: "fio"
	  ROOT: /    CWD: /ws/mytools/test/fio
	   FD       FILE            DENTRY           INODE       TYPE PATH
	    3 ffff880027172400 ffff880027678c00 ffff880077bf99a8 REG  /mnt/test

	  PID: 19671  TASK: ffff880035284140  CPU: 0   COMMAND: "fio"
	  ROOT: /    CWD: /ws/mytools/test/fio
	   FD       FILE            DENTRY           INODE       TYPE PATH
	    3 ffff880027170500 ffff880027678c00 ffff880077bf99a8 REG  /mnt/test

  可以看到，输出中分别给出了两个 /mnt/test 文件的各自的 `struct file`，`struct dentry` 和 `struct inode` 的数据结构地址。

- 利用上一步得到的地址，查看 `struct file` 的文件操作表地址和地址空间地址，

	  crash> struct file.f_op,f_mapping ffff880027172400
	    f_op = 0xffffffffa0777940 <ext4_file_operations>
	    f_mapping = 0xffff880077bf9b10

- 利用之前得到的地址，查看 `struct dentry` 的 `d_name` 和 `d_inode` 地址。可以看出，输出与之前的结构吻合。

	  crash> dentry.d_name,d_inode ffff880027678c00
	    d_name = {
	      {
	        {
	          hash = 3378392626,
	          len = 4
	        },
	        hash_len = 20558261810
	      },
	      name = 0xffff880027678c38 "test"
	    }
	    d_inode = 0xffff880077bf99a8

- 利用之前得到的地址，查看 `struct inode` 的文件操作表地址和地址空间地址，发现与之前 `struct file` 的文件操作表地址和地址空间地址是一致的。
  如前所述，这是因为，`struct file` 的这两个操作表就是从 `struct inode` 对应的成员复制过来的。

	  crash> inode.i_fop,i_mapping ffff880077bf99a8
	    i_fop = 0xffffffffa0777940 <ext4_file_operations>
	    i_mapping = 0xffff880077bf9b10

- 根据地址空间地址，可以查看其对应的地址空间操作表地址，

	  crash> address_space.a_ops 0xffff880077bf9b10
	    a_ops = 0xffffffffa0777ec0 <ext4_da_aops>

- 由于 /mnt/test 在 Ext4 文件系统中创建，因此文件系统操作表被初始化为 `ext4_file_operations`。其内容可以打印如下，

	  crash> p ext4_file_operations
	  ext4_file_operations = $10 = {
	    owner = 0x0,
	    llseek = 0xffffffffa07230c0 <ext4_llseek>,
	    read = 0x0,
	    write = 0x0,
	    read_iter = 0xffffffff81191340 <generic_file_read_iter>,
	    write_iter = 0xffffffffa0722a40 <ext4_file_write_iter>,
	    iterate = 0x0,
	    poll = 0x0,
	    unlocked_ioctl = 0xffffffffa0730f70 <ext4_ioctl>,
	    compat_ioctl = 0xffffffffa0732380 <ext4_compat_ioctl>,
	    mmap = 0xffffffffa0722940 <ext4_file_mmap>,
	    open = 0xffffffffa0722780 <ext4_file_open>,
	    flush = 0x0,
	    release = 0xffffffffa0723470 <ext4_release_file>,
	    fsync = 0xffffffffa0723530 <ext4_sync_file>,
	    aio_fsync = 0x0,
	    fasync = 0x0,
	    lock = 0x0,
	    sendpage = 0x0,
	    get_unmapped_area = 0x0,
	    check_flags = 0x0,
	    flock = 0x0,
	    splice_write = 0xffffffff81249100 <iter_file_splice_write>,
	    splice_read = 0xffffffff81249d30 <generic_file_splice_read>,
	    setlease = 0x0,
	    fallocate = 0xffffffffa075c920 <ext4_fallocate>,
	    show_fdinfo = 0x0,
	    copy_file_range = 0x0,
	    clone_file_range = 0x0,
	    dedupe_file_range = 0x0
	  }

- 而 /mnt/test 对应的地址空间操作表内容也可以打印如下，

	  crash> p ext4_da_aops
	  ext4_da_aops = $11 = {
	    writepage = 0xffffffffa072b030 <ext4_writepage>,
	    readpage = 0xffffffffa0726f90 <ext4_readpage>,
	    writepages = 0xffffffffa072c0b0 <ext4_writepages>,
	    set_page_dirty = 0x0,
	    readpages = 0xffffffffa0726b40 <ext4_readpages>,
	    write_begin = 0xffffffffa072dbf0 <ext4_da_write_begin>,
	    write_end = 0xffffffffa072e7d0 <ext4_da_write_end>,
	    bmap = 0xffffffffa0727ed0 <ext4_bmap>,
	    invalidatepage = 0xffffffffa0727b90 <ext4_da_invalidatepage>,
	    releasepage = 0xffffffffa07266f0 <ext4_releasepage>,
	    freepage = 0x0,
	    direct_IO = 0xffffffffa07281b0 <ext4_direct_IO>,
	    migratepage = 0xffffffff811f9370 <buffer_migrate_page>,
	    launder_page = 0x0,
	    is_partially_uptodate = 0xffffffff8124d950 <block_is_partially_uptodate>,
	    is_dirty_writeback = 0x0,
	    error_remove_page = 0xffffffff811a08e0 <generic_error_remove_page>,
	    swap_activate = 0x0,
	    swap_deactivate = 0x0
	  }

仔细对比前面几小节内容，我们即可清除直观的了解到，Ext4 文件系统是如何初始化 VFS 层提供的文件操作表和地址空间操作表的。

关于 Linux Crash 命令的使用，请参考延伸阅读的相关文章。

## 5. 小结

本文基于 `fio` 的测试用例，通过 Flamegraph 和 functongraph 等工具，结合源代码来进一步理解其中涉及到的文件 IO 操作。
一般说来，从学习源码角度看，Flamegraph 更适合对被研究的代码和功能做一个全局的疏理，而 `functongraph` 则更适合研究代码实现的细节。

通过这些简单的了解，我们可以对 `write` 和 `fadvise64` 做较为深入地比较，以充分了解为什么两个函数在执行时间上有如此大差异。

此外，我们也可以借助 Linux Crash 工具，对 Linux 内核的关键数据结构以只读方式查看，帮助我们直观了解内核实现。进一步信息，请参考延伸阅读章节列出的文章。

## 6. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2/)
* [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/)
* [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf)
* [Flamegraph 相关资源](http://www.brendangregg.com/flamegraphs.html)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Device Drivers, Third Edition](http://lwn.net/Kernel/LDD3)
* [Ftrace: Function Tracer](https://github.com/torvalds/linux/blob/master/Documentation/trace/ftrace.txt)
* [The iov_iter interface](https://lwn.net/Articles/625077/)
* [Toward a safer fput](https://lwn.net/Articles/494158/)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background)
* [Linux Crash - coding notes](http://oliveryang.net/2015/07/linux-crash-coding-notes/)
* [Linux Crash White Paper (了解 crash 命令)](http://people.redhat.com/anderson/crash_whitepaper)
