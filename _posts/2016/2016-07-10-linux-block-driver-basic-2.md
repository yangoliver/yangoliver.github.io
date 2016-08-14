---
layout: post
title: Linux Block Driver - 2
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, kernel, linux, storage]
---

> 文本处于写作状态，内容随时可能有更改。

> 本文首发于<http://oliveryang.net>，转载时请包含原文或者作者网站链接。

* content
{:toc}

## 1. 背景

在 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中，我们实现了一个最简块设备驱动 Sampleblk。
这个只有 200 多行源码的块设备驱动利用内存创建了标准的 Linux 磁盘。我们在基于 Linux 4.6.0 内核的环境下，加载该驱动，并在其上创建了 Ext4 文件系统。

本文将继续之前的实验，围绕 Sampleblk 探究 Linux 块设备驱动的运作机制。

## 2. 准备


首先，在阅读本文前，请按照 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
中的步骤准备好实验环境。确保可以做到如下步骤，

- 编译和加载 Sampleblk Day1 驱动
- 用 Ext4 格式化 /dev/sampleblk1
- mount 文件系统到 /mnt

其次，为了继续后续实验，还需做如下准备工作。

- 安装 fio 测试软件。

  [fio](https://github.com/axboe/fio) 是目前非常流行的 IO 子系统测试工具。作者 Jens Axboe 是 Linux IO 子系统的 maintainer，目前就职于 Facebook。
  互联网上 FIO 安装和使用的文章很多，这里就不在赘述。不过最值得细读的还是 [fio HOWTO](https://github.com/axboe/fio/blob/master/HOWTO)。

- 安装 blktrace 工具。

  也是 Jens Axboe 开发的 IO 子系统追踪和性能调优工具。发行版有安装包。关于该工具的使用可以参考 [blktrace man page](http://linux.die.net/man/8/blktrace)。

- 安装 Linux Perf 工具。

  Perf 是 Linux 源码树自带工具，运行时动态追踪，性能分析的利器。也可以从发行版找到安装包。
  网上的 Perf 使用介绍很多。[Perf Wiki](https://perf.wiki.kernel.org/index.php/Main_Page) 非常值得一看。

- 下载 perf-tools 脚本。

  [perf-tools 脚本](https://github.com/brendangregg/perf-tools) 是 Brendan Gregg 写的基于 ftrace 和 perf 的工具脚本。全部由 bash 和 awk 写成，无需安装，非常简单易用。
  [Ftrace: The hidden light switch](http://lwn.net/Articles/608497) 这篇文章是 Brendan Gregg 给 LWN 的投稿，推荐阅读。 

## 3. 实验与分析

### 3.1 文件顺序写测试

如一般 Linux 测试工具支持命令行参数外，fio 也支持 job file 的方式定义测试参数。
本次实验中使用的 [fs_seq_write_sync_001](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/fs_seq_write_sync_001) job file 内容如下，

	; -- start job file --
	[global]            ; global shared parameters
	filename=/mnt/test  ; location of file in file system
	rw=write            ; sequential write only, no read
	ioengine=sync       ; synchronized, write(2) system call
	bs=,4k              ; fio iounit size, write=4k, read and trim are default(4k)
	iodepth=1           ; how many in-flight io unit
	size=2M             ; total size of file io in one job
	loops=1000000       ; number of iterations of one job

	[job1]              ; job1 specific parameters

	[job2]              ; job2 specific parameters
	; -- end job file --

本次实验将在 /dev/sampleblk1 上 mount 的 Ext4 文件系统上进行顺序 IO 写测试。其中 fio 将启动两个测试进程，同时对 /mnt/test 文件进行写操作。

	$ sudo fio ./fs_seq_write_sync_001
	job1: (g=0): rw=write, bs=4K-4K/4K-4K/4K-4K, ioengine=sync, iodepth=1
	job2: (g=0): rw=write, bs=4K-4K/4K-4K/4K-4K, ioengine=sync, iodepth=1
	fio-2.1.10
	Starting 2 processes
	^Cbs: 2 (f=2): [WW] [58.1% done] [0KB/2208MB/0KB /s] [0/565K/0 iops] [eta 13m:27s]
	...[snipped]...
	fio: terminating on signal 2

	job1: (groupid=0, jobs=1): err= 0: pid=22977: Thu Jul 21 22:10:28 2016
	  write: io=1134.8GB, bw=1038.2MB/s, iops=265983, runt=1118309msec
	    clat (usec): min=0, max=66777, avg= 1.63, stdev=21.57
	     lat (usec): min=0, max=66777, avg= 1.68, stdev=21.89
	    clat percentiles (usec):
	     |  1.00th=[    0],  5.00th=[    1], 10.00th=[    1], 20.00th=[    1],
	     | 30.00th=[    1], 40.00th=[    1], 50.00th=[    2], 60.00th=[    2],
	     | 70.00th=[    2], 80.00th=[    2], 90.00th=[    2], 95.00th=[    3],
	     | 99.00th=[    4], 99.50th=[    7], 99.90th=[   18], 99.95th=[   25],
	     | 99.99th=[  111]
	    lat (usec) : 2=49.79%, 4=49.08%, 10=0.71%, 20=0.34%, 50=0.06%
	    lat (usec) : 100=0.01%, 250=0.01%, 500=0.01%, 750=0.01%, 1000=0.01%
	    lat (msec) : 2=0.01%, 4=0.01%, 10=0.01%, 20=0.01%, 50=0.01%
	    lat (msec) : 100=0.01%
	  cpu          : usr=8.44%, sys=69.65%, ctx=1935732, majf=0, minf=9
	  IO depths    : 1=100.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
	     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
	     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
	     issued    : total=r=0/w=297451591/d=0, short=r=0/w=0/d=0
	     latency   : target=0, window=0, percentile=100.00%, depth=1
	job2: (groupid=0, jobs=1): err= 0: pid=22978: Thu Jul 21 22:10:28 2016
	  write: io=1137.4GB, bw=1041.5MB/s, iops=266597, runt=1118309msec
	    clat (usec): min=0, max=62132, avg= 1.63, stdev=21.35
	     lat (usec): min=0, max=62132, avg= 1.68, stdev=21.82

	...[snipped]...

	Run status group 0 (all jobs):
	  WRITE: io=2271.2GB, aggrb=2080.5MB/s, minb=1038.2MB/s, maxb=1041.5MB/s, mint=1118309msec, maxt=1118309msec

	Disk stats (read/write):
	  sda: ios=0/4243062, merge=0/88, ticks=0/1233576, in_queue=1232723, util=37.65%

从 fio 的输出中可以看到 fio 启动了两个 job，并且按照 job file 规定的设置开始做文件系统写测试。
在测试进行到 58.1%  的时候，我们中断程序，得到了上述的输出。从输出中我们得出如下结论，

- 两个线程总共的写的吞吐量为 2080.5MB/s，在磁盘上的 IPOS 是 4243062。
- 每个线程的平局延迟为 1.68us，方差是 21.8 左右。
- 磁盘 IO merge 很少，磁盘的利用率也只有 37.65%。
- 线程所在处理器的时间大部分在内核态：69.65%，用户态时间只有 8.44% 。

### 3.2 文件 IO Pattern 分析

#### 3.2.1 使用 strace

首先，我们可以先了解一下 fio 测试在系统调用层面看的 IO pattern 是如何的。Linux 的 `strace` 工具是跟踪应用使用系统调用的常用工具。

在 fio 运行过程中，我们获得 fio 其中一个 job 的 pid 之后，运行了如下的 `strace` 命令，

	$ sudo strace -ttt -T -e trace=desc -C -o ~/strace_fio_fs_seq_write_sync_001.log -p 94302

[`strace` man page](http://linux.die.net/man/1/strace) 给出了命令的详细用法，这里只对本小节里用到的各个选项做简单的说明，

- `-ttt` 打印出每个系统调用发生的起始时间戳。
- `-T` 则给出了每个系统调用的开销。
- `-e trace=desc` 只记录文件描述符相关系统调用。这样可过滤掉无关信息，因为本实验是文件顺序写测试。
- `-C` 则在 `strace` 退出前可以给出被跟踪进程的系统调用在 `strace` 运行期间使用比例和次数的总结。
- `-o` 则指定把 `strace` 的跟踪结果输出到文件中去。

#### 3.2.2 分析 strace 日志

根据 strace 的跟踪日志，我们可对本次 fio 测试的 IO pattern 做一个简单的分析。
详细日志信息请访问[这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/strace_fio_fs_seq_write_sync_001.log)，下面只给出其中的关键部分，

	1466326568.892873 open("/mnt/test", O_RDWR|O_CREAT, 0600) = 3 <0.000013>
	1466326568.892904 fadvise64(3, 0, 2097152, POSIX_FADV_DONTNEED) = 0 <0.000813>
	1466326568.893731 fadvise64(3, 0, 2097152, POSIX_FADV_SEQUENTIAL) = 0 <0.000004>
	1466326568.893744 write(3, "\0\260\35\0\0\0\0\0\0\320\37\0\0\0\0\0\0\300\35\0\0\0\0\0\0\340\37\0\0\0\0\0"..., 4096) = 4096 <0.000020>

	[...snipped (512 write system calls)...]

	1466326568.901551 write(3, "\0p\27\0\0\0\0\0\0\320\37\0\0\0\0\0\0\300\33\0\0\0\0\0\0\340\37\0\0\0\0\0"..., 4096) = 4096 <0.000006>
	1466326568.901566 close(3)              = 0 <0.000008>

	[...snipped (many iterations of open, fadvise64, write, close)...]

	% time     seconds  usecs/call     calls    errors syscall
	------ ----------- ----------- --------- --------- ----------------
	 72.55    0.192610           2     84992           write
	 27.04    0.071788         216       332           fadvise64
	  0.28    0.000732           4       166           open
	  0.13    0.000355           2       166           close
	------ ----------- ----------- --------- --------- ----------------
	100.00    0.265485                 85656           total

根据 `strace` 日志，我们就可以轻松分析这个 fio 测试的 IO Pattern 是如何的了，

1. 首先调用 `open` 在 Ext4 上以读写方式打开 /mnt/test 文件，若不存在则创建一个。

   因为 fio job file 指定了文件名，filename=/mnt/test
2. 调用 `fadvise64`，使用 `POSIX_FADV_DONTNEED` 把 /mnt/test 在 page cache 里的数据 flush 到磁盘。

   fio 做文件 IO 前，清除 /mnt/test 文件的 page cache，可以让测试避免受到 page cache 影响。

3. 调用 `fadvise64`，使用 `POSIX_FADV_SEQUENTIAL` 提示内核应用要对 /mnt/test 做顺序 IO 操作。

   这是因为 fio job file 定义了 rw=write，因此这是顺序写测试。
4. 调用 `write` 对 /mnt/test 写入 4K 大小的数据。一共 write 512 次，共 2M 数据。

   这是因为 fio job file 定义了 ioengine=sync，bs=,4k，size=2M。

5. 最后，调用 `close` 完成一次 /mnt/test 顺序写测试。重复上述过程，反复迭代。

   fio job file 定义了 loops=1000000

另外，根据 `strace` 日志的系统调用时间和调用次数的总结，我们可以得出如下结论，

- 系统调用 `open`，`write` 和 `close` 的开销非常小，只有几微秒。
- 测试中 `write` 调用次数最多，虽然单次 `write` 只有几微妙，但积累总时间最高。
- 测试中 `fadvise64` 调用次数比 `write` 少，但 `POSIX_FADV_DONTNEED` 带来的 flush page cache 的操作可以达到几百微秒。

#### 3.2.3 使用 SystemTap

使用 `strace` 虽然可以拿到单次系统调用读写的字节数，但对大量的 IO 请求来说，不经过额外的脚本处理，很难得到一个总体的认识和分析。
但是，我们可以通过编写 SystemTap 脚本来对这个测试的 IO 请求大小做一个宏观的统计，并且使用直方图来直观的呈现这个测试的文件 IO 尺寸分布。

启动 fio 测试后，只需要运行如下命令，即可收集到指定 PID 的文件 IO 的统计信息，

	$ sudo ./fiohist.stp 94302
	starting probe
	^C
	IO Summary:

	                                       read     read             write    write
	            name     open     read   KB tot    B avg    write   KB tot    B avg
	             fio     7917        0        0        0  3698312 14793248     4096

	Write I/O size (bytes):

	process name: fio
	value |-------------------------------------------------- count
	 1024 |                                                         0
	 2048 |                                                         0
	 4096 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  3698312
	 8192 |                                                         0
	16384 |                                                         0

可以看到，直方图和统计数据显示，整个跟踪数据收集期间都是 4K 字节的 write 写操作，而没有任何读操作。而且，在此期间，没有任何 `read` IO 操作。
同时，由于 `write` 系统调用参数并不提供文件内的偏移量，所以我们无法得知文件的写操作是否是随机还是顺序的。

但是，如果是文件的随机读写 IO，应该可以在 `strace` 时观测到 `lseek` + `read` 或 `write` 调用。这也从侧面可以推测测试是顺序写 IO。
此外，`pread` 和 `pwrite` 系统调用提供了文件内的偏移量，有这个偏移量的数据，即可根据时间轴画出 IO 文件内偏移的 [Heatmap](https://en.wikipedia.org/wiki/Heat_map)。
通过该图，即可直观地判断是否是随机还是顺序 IO 了。

本例中的 SystemTap 脚本 [fiohist.stp](https://github.com/yangoliver/mytools/blob/master/debug/systemtap/fiohist.stp) 是作者个人为分析本测试所编写。
详细代码请参考文中给出的源码链接。此外，在 [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/) 这篇文章里收录了关于在自编译内核上运行 SystemTap 脚本的一些常见问题。

### 3.3 On CPU Time 分析

运行 fio 测试期间，我们可以利用 Linux `perf`， 对系统做 ON CPU Time 分析。这样可以进一步获取如下信息，

- 在测试中，软件栈的哪一部分消耗了主要的 CPU 资源。可以帮助我们确定 CPU 时间优化的主要方向。

- 通过查看消耗 CPU 资源的软件调用栈，了解函数调用关系。

- 利用可视化工具，如 Flamgraph，对 Profiling 的大量数据做直观的呈现。方便进一步分析和定位问题。

#### 3.3.1 使用 perf

首先，当 fio 测试进入稳定状态，运行 `perf record` 命令，

	# perf record -a -g --call-graph dwarf -F 997 sleep 60

其中主要的命令行选项如下，

- `-F` 选项指定 `perf` 以 `997` 次每秒的频率对 CPU 上运行的用户进程或者内核上下文进行采样 (Sampling)。

  由于 Linux 内核的时钟中断是以 `1000` 次每秒的频率周期触发，所以按照 `997` 频率采样可以避免每次采样都采样到始终中断相关的处理，减少干扰。

- `-a` 选项指定采样系统中所有的 CPU。

- `-g` 选项指定记录下用户进程或者内核的调用栈。

  其中，`--call-graph dwarf` 指定调用栈收集的方式为 `dwarf`，即 `libdwarf` 和 `libdunwind` 的方式。Perf 还支持 `fp` 和 `lbs` 方式。

- `sleep 60` 则是通过 `perf` 指定运行的命令，这个命令起到了让 `perf` 运行 60 秒然后退出的效果。

在 `perf record` 之后，运行 `perf report` 查看采样结果的汇总，

	# sudo perf report --stdio

	[...snipped...]

	27.51%     0.10%  fio    [kernel.kallsyms]      [k] __generic_file_write_iter
	                    |
	                    ---__generic_file_write_iter
	                       |
	                       |--99.95%-- ext4_file_write_iter
	                       |          __vfs_write
	                       |          vfs_write
	                       |          sys_write
	                       |          do_syscall_64
	                       |          return_from_SYSCALL_64
	                       |          0x7ff91cd381cd
	                       |          fio_syncio_queue
	                       |          td_io_queue
	                       |          thread_main
	                       |          run_threads
	                        --0.05%-- [...]
	[...snipped...]

#### 3.3.2 使用 Flamegraph

使用 [Flamegraph](https://github.com/brendangregg/FlameGraph)，可以把前面产生的 `perf record` 的结果可视化，生成火焰图。
运行如下命令，

	# perf script | stackcollapse-perf.pl > out.perf-folded
	# cat out.perf-folded | flamegraph.pl > flamegraph_on_cpu_perf_fs_seq_write_sync_001.svg

然后，即可生成如下火焰图，

<img src="/media/images/2016/flamegraph_on_cpu_perf_fs_seq_write_sync_001.svg" width="100%" height="100%" />

该火焰图是 SVG 格式的矢量图，基于 XML 文件定义。在浏览器里右击在新窗口打开图片，即可进入与**火焰图的交互模式**。该模式下，统计数据信息和缩放功能都可以移动和点击鼠标来完成交互。
通过在交互模式下浏览和缩放火焰图，我们可以得出如下结论，

- `perf record` 共有 119644 个采样数据，将此定义为 100% CPU 时间。
- `fio` 进程共有 91079 个采样数据，占用 76.13% 的 CPU 时间。

  `fio` 的 `fio_syncio_queue` 用掉了 48.53% 的 CPU，其中绝大部分时间在内核态，`sys_write` 系统调用就消耗了 45.78%。

  `fio` 的 `file_invalidate_cache` 函数占用了 20.88% 的 CPU，其中大部分都在内核态，`sys_fadvise64` 系统调用消耗了 20.81%。

  在这里我们注意到，`sys_write` 和 `sys_fadvise64` 系统调用 CPU 占用资源的比例是 2:1。而之前 `strace` 得出的两个系统调用消耗时间的比例是 3:1。
  这就意味着，`sys_write` 花费了很多时间在**睡眠态**。

- 在 Ext4 文件系统的写路径，存在热点锁。

  `ext4_file_write_iter` 函数里的 inode mutex 的 mutex 自旋等待时间，占用了 16.93% 的 CPU。与 `sys_write` 系统调用相比，CPU 消耗占比达到三分之一强。

- `swapper` 为内核上下文，包含如下部分，

   `native_safe_halt` 代表 CPU 处于 IDEL 状态，共有两次，9.04% 和 9.18%。

   `smp_reschedule_interrupt` 代表 CPU 处理调度器的 IPI 中断，用于处理器间调度的负载均衡。共有两次，1.66％ 和 1.61%。这部分需要方大矢量图移动鼠标到相关函数才能看到。

- `kblockd` 工作队列线程。

   由 `block_run_queue_async` 触发，最终调用 `__blk_run_queue` 把 IO 发送到下层的 sampleblk 块驱动。共有两部份，合计 0.88%。
- `rcu_gp_kthread` 处理 RCU 的内核线程，占用 0.04 % 的 CPU 时间。

综合以上分析，我们可以看到，火焰图不但可以帮助我们理解 CPU 全局资源的占用情况，而且还能进一步分析到微观和细节。例如局部的热锁，父子函数的调用关系，和所占 CPU 时间比例。

## 4. 深入理解文件 IO

为什么 `write` 和 `fadvise64` 调用的执行时间差异如此之大？如果对操作系统 page cache 的工作原理有基本概念的话，这个问题并不难理解，

- Page cache 加速了文件读写操作

  一般而言，`write` 系统调用虽然是同步 IO，但 IO 数据是写入 page cache 就立即返回的，因此实际开销是写内存操作，而且只写入 page cache 里，不会对块设备发起 IO 操作。
  应用如果需要保证数据写到磁盘上，必需在 `write` 调用之后调用 `fsync` 来保证文件数据在 `fsync` 返回前把数据从 page cache 甚至硬盘的 cache 写入到磁盘介质。

- Flush page cache 会带来额外的开销

  虽然 page cache 加速了文件系统的读写操作，但一旦需要 flush page cache，将集中产生大量的磁盘 IO 操作。磁盘 IO 操作比写 page cache 要慢很多。因此，flush page cache 非常费时而且影响性能。

由于 Linux 内核提供了强大的动态追踪 (Dynamic Trace) 能力，现在我们可以通过内核的 trace 工具来了解 `write` 和 `fadvise64` 调用的执行时间差异。

### 4.1 使用 Ftrace

Linux `strace` 只能追踪系统调用界面这层的信息。要追踪系统调用内部的机制，就需要借助 Linux 内核的 trace 工具了。Ftrace 就是非常简单易用的追踪系统调用内部实现的工具。
Linux 源码树里的 [Documentation/trace/ftrace.txt](https://github.com/torvalds/linux/blob/master/Documentation/trace/ftrace.txt) 就是极好的入门材料。

不过，Ftrace 的 UI 是基于 linux debugfs 的。操作起来有些繁琐。
因此，我们用 Brendan Gregg 写的 [funcgraph](https://github.com/brendangregg/perf-tools/blob/master/examples/funcgraph_example.txt) 来简化我们对 Ftrace 的使用。
这个工具是基于 Ftrace 的用 bash 和 awk 写的脚本，非常容易理解和使用。
关于 Brendan Gregg 的 perf-tools 的使用，请阅读 [Ftrace: The hidden light switch](http://lwn.net/Articles/608497) 这篇文章。

### 4.2 open

运行 fio 测试时，用 `funcgraph` 可以获取 `open` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_open

详细的 `open` 系统调用函数图日志可以查看 [这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_open_fs_seq_write_sync_001.log)。

仔细察看函数图日志就会发现，`open` 系统调用并没有调用块设备驱动的代码，而只做了如下处理，

- 首先，VFS 层的 `open` 系统调用代码为进程分配 fd，根据文件名查找元数据，为文件分配和初始化 `struct file`。在这一层的元数据查找、读取，以及文件的打开都会调用到底层具体文件系统的回调函数协助完成。
  最后在系统调用返回前，把 fd，和 `struct file` 装配到进程的 `struct task_struct` 上。
- Ext4 注册在 VFS 层的入口函数被上层调用，为上层查找元数据 (ext4_lookup)，创建文件 (ext4_create)，打开文件 (ext4_file_open) 提供服务。
  本例中，由于文件已经被创建，而且元数据已经缓存在内存中，因此，只涉及到 ext4_file_open 的代码。

### 4.3 fadvise64

用 `funcgraph` 也可以获取 `fadvise64` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_fadvise64

详细的 `fadvise64` 系统调用的跟踪日志请查看[这里](https://raw.githubusercontent.com/yangoliver/lktm/master/drivers/block/sampleblk/labs/lab1/funcgraph_fadvise_fs_seq_write_sync_001.log)。

根据 [fadvise64(2)](http://linux.die.net/man/2/fadvise64)，这个系统调用的作用是预先声明文件数据的访问模式。

从前面 `strace` 的日志里我们得知，每次 `open` 文件之后，`fio` 都会调用两次 `fadvise64` 系统调用，只不过两次的 `advise` 参数使用有所差别，因而起到的作用也不同。
下面就对本实验中涉及到的两个 `advise` 参数做简单介绍。

#### 4.3.1 POSIX_FADV_SEQUENTIAL

POSIX_FADV_SEQUENTIAL 主要是应用用来通知内核，它打算以顺序的方式去访问文件数据。

如果参考我们获得的 `fadvise64` 系统调用的函数图，再结合源码，我们知道，POSIX_FADV_SEQUENTIAL 的实现非常简单，主要有以下两方面，

1. 把 VFS 层文件的预读窗口增大到默认的两倍。
2. 把文件对应的内核结构 `struct file` 的文件模式 `file->f_mode` 的随机访问 `FMODE_RANDOM` 标志位清除掉。从而让 VFS 预读算法对顺序读更高效。

由于以上操作仅仅涉及简单内存访问操作，因此在 `fadvise64` 系统调用的函数图里，我们可以看到它仅仅用了 0.891 us 就返回了，远远快于另外一个命令。

综上所述，POSIX_FADV_SEQUENTIAL 操作的代码路径下，全都是对文件系统预读的优化。而本文中的 `fio` 测试只有顺序写操作，因此，POS IX_FADV_SEQUENTIAL 的操作对本测试没有任何影响。

#### 4.3.2 POSIX_FADV_DONTNEED

POSIX_FADV_DONTNEED 则是应用通知内核，与文件描述符 `fd` 关联的文件的指定范围 (`offset` 和 `len` 描述)的 page cache 都不需要了，脏页可以刷到盘上，然后直接丢弃了。

Linux 提供了全局刷 page cache 到磁盘，然后丢弃 page cache 的接口: /proc/sys/vm/drop_pagecache。然而 `fadvise64` 的 POSIX_FADV_DONTNEED 作用域是文件内的某段范围，具有更细的粒度。

在我们 `fadvise64` 系统调用的跟踪日志里，调用图关系最复杂，返回时间最长的就是这个命令了。
但如果参考其源码实现，其实该命令主要分为两大步骤，

1. 回写 (Write Back) 页缓存。
2. 清除 (Invalidate) 页缓存。

##### 4.3.2.1 回写页缓存

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

##### 4.3.2.2 清除页缓存

将文件对应的指定范围的 page cache **尽可能**清除 (Invalidate)。之所以是尽可能，是因为这个清除操作会跳过一些页面，从而避免等待块 IO 完成。例如，脏页，和被加锁的页面。

TBD.

### 4.4 write

用 `funcgraph` 也可以获取 `write` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_write

详细的 `write` 系统调用的跟踪日志请查看[这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_write_fs_seq_write_sync_001.log)。

TBD

### 4.5 close

用 `funcgraph` 也可以获取 `close` 系统调用的内核函数的函数图 (function graph)，

	$ sudo ./funcgraph -d 1 -p 95069 SyS_close

详细的 `close` 系统调用的跟踪日志请查看[这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/funcgraph_close_fs_seq_write_sync_001.log)。

TBD

## 5. 小结

TBD

## 6. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Device Drivers, Third Edition](http://lwn.net/Kernel/LDD3)
* [Ftrace: Function Tracer](https://github.com/torvalds/linux/blob/master/Documentation/trace/ftrace.txt)
