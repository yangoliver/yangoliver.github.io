---
layout: post
title: Linux Block Driver - 3
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

> 文本处于写作状态，内容随时可能有更改。

> 本文首发于<http://oliveryang.net>，转载时请包含原文或者作者网站链接。

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

运行 fio 测试时，用 `funcgraph` 可以获取 `open` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_open

详细的 `open` 系统调用函数图日志可以查看 [这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_open_fs_seq_write_sync_001.log)。

仔细察看函数图日志就会发现，`open` 系统调用并没有调用块设备驱动的代码，而只做了如下处理，

- 首先，VFS 层的 `open` 系统调用代码为进程分配 fd，根据文件名查找元数据，为文件分配和初始化 `struct file`。在这一层的元数据查找、读取，以及文件的打开都会调用到底层具体文件系统的回调函数协助完成。
  最后在系统调用返回前，把 fd，和 `struct file` 装配到进程的 `struct task_struct` 上。
- Ext4 注册在 VFS 层的入口函数被上层调用，为上层查找元数据 (ext4_lookup)，创建文件 (ext4_create)，打开文件 (ext4_file_open) 提供服务。
  本例中，由于文件已经被创建，而且元数据已经缓存在内存中，因此，只涉及到 ext4_file_open 的代码。

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
     * 调用 `iov_iter_copy_from_user_atomic` 把 `sys_write` 系统调用用户态 buffer 里的数据拷贝到 `write_begin` 方法返回的页面。
     * 调用文件系统的 `write_end` 方法，即 `ext4_da_write_end`。

TBD.

### 3.5 close

用 `funcgraph` 也可以获取 `close` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_close

详细的 `close` 系统调用的跟踪日志请查看[这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_close_fs_seq_write_sync_001.log)。

TBD

## 4. 小结

TBD

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
