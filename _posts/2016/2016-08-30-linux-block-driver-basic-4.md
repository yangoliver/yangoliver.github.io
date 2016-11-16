---
layout: post
title: Linux Block Driver - 4
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

>转载时请包含原文或者作者网站链接：<http://oliveryang.net>


* content
{:toc}

## 1. 背景

让我们梳理一下本系列文章整体脉络。

* 首先，[Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 介绍了一个只有 200 行源码的 Sampleblk 块驱动的实现。
* 然后，在 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中，我们在 Sampleblk 驱动创建了 Ext4 文件系统，并做了一个 `fio` 顺序写测试。
  测试中我们利用 Linux 的各种跟踪工具，对这个 `fio` 测试做了一个性能个性化分析。
* 而在 [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3) 中，我们利用 Linux 跟踪工具和 Flamegraph 来对文件系统层面上的文件 IO 内部实现，有了一个概括性的了解。

本文将继续之前的实验，围绕这个简单的 `fio` 测试，探究 Linux 块设备驱动的运作机制。除非特别指明，本文中所有 Linux 内核源码引用都基于 4.6.0。其它内核版本可能会有较大差异。

## 2. 准备

阅读本文前，可能需要如下准备工作，

- 参考 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中的内容，加载该驱动，格式化设备，装载 Ext4 文件系统。
- 按照 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中的步骤，运行 `fio` 测试。

本文将在与前文完全相同 `fio` 测试负载下，在块设备层面对该测试做进一步的分析。

## 3. Block IO Pattern 分析

### 3.1 写请求大小

Linux 4.6 内核的块设备层的预定义了 19 个通用块层的 tracepoints。这些 tracepoints，可以通过如下 perf 命令来列出来，

	$ sudo perf list  block:*

	List of pre-defined events (to be used in -e):

	  block:block_bio_backmerge                          [Tracepoint event]
	  block:block_bio_bounce                             [Tracepoint event]
	  block:block_bio_complete                           [Tracepoint event]
	  block:block_bio_frontmerge                         [Tracepoint event]
	  block:block_bio_queue                              [Tracepoint event]
	  block:block_bio_remap                              [Tracepoint event]
	  block:block_dirty_buffer                           [Tracepoint event]
	  block:block_getrq                                  [Tracepoint event]
	  block:block_plug                                   [Tracepoint event]
	  block:block_rq_abort                               [Tracepoint event]
	  block:block_rq_complete                            [Tracepoint event]
	  block:block_rq_insert                              [Tracepoint event]
	  block:block_rq_issue                               [Tracepoint event]
	  block:block_rq_remap                               [Tracepoint event]
	  block:block_rq_requeue                             [Tracepoint event]
	  block:block_sleeprq                                [Tracepoint event]
	  block:block_split                                  [Tracepoint event]
	  block:block_touch_buffer                           [Tracepoint event]
	  block:block_unplug                                 [Tracepoint event]

我们可以利用 `block:block_rq_insert` 来跟踪获取 `fio` 测试时，该进程写往块设备 /dev/sampleblk1 IO 请求的起始扇区地址和扇区数量，

	$ sudo perf record -a -g --call-graph dwarf -e block:block_rq_insert sleep 10

因为我们指定了记录调用栈的信息，所以，`perf script` 可以获取 `fio` 从用户态到内核 `block:block_rq_insert` tracepoint 的完整调用栈的信息。
并且，给出了主次设备号，相关操作，及起始扇区和扇区数，

	$ sudo perf script | head -n 20
	fio 73790 [000] 1011438.379090: block:block_rq_insert: 253,1 W 0 () 3510 + 255 [fio]
		          5111e1 __elv_add_request (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          518e64 blk_flush_plug_list (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          51910b blk_queue_bio (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          517453 generic_make_request (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          517597 submit_bio (/lib/modules/4.6.0-rc3+/build/vmlinux)
		           107de ext4_io_submit ([ext4])
		            c6bc ext4_writepages ([ext4])
		          39cd3e do_writepages (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          390b66 __filemap_fdatawrite_range (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          3d5d96 sys_fadvise64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          203c12 do_syscall_64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
		          8bb721 return_from_SYSCALL_64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
		    7fd1e61d7d4d posix_fadvise64 (/usr/lib64/libc-2.17.so)
		          4303b3 file_invalidate_cache (/usr/local/bin/fio)
		          41a79b td_io_open_file (/usr/local/bin/fio)
		          43f40d get_io_u (/usr/local/bin/fio)
		          45ad89 thread_main (/usr/local/bin/fio)
		          45cffc run_threads (/usr/local/bin/fio)
    [...snipped...]

使用简单的处理，我们即可发现这个测试在通用块层的 IO Pattern,


	$ sudo perf script | grep lock_rq_insert | head -n 20
	fio 71005 [000] 977641.575503: block:block_rq_insert: 253,1 W 0 () 3510 + 255 [fio]
	fio 71005 [000] 977641.575566: block:block_rq_insert: 253,1 W 0 () 3765 + 255 [fio]
	fio 71005 [000] 977641.575568: block:block_rq_insert: 253,1 W 0 () 4020 + 255 [fio]
	fio 71005 [000] 977641.575568: block:block_rq_insert: 253,1 W 0 () 4275 + 255 [fio]
	fio 71005 [000] 977641.575569: block:block_rq_insert: 253,1 W 0 () 4530 + 255 [fio]
	fio 71005 [000] 977641.575570: block:block_rq_insert: 253,1 W 0 () 4785 + 255 [fio]
	fio 71005 [000] 977641.575570: block:block_rq_insert: 253,1 W 0 () 5040 + 255 [fio]
	fio 71005 [000] 977641.575571: block:block_rq_insert: 253,1 W 0 () 5295 + 255 [fio]
	fio 71005 [000] 977641.575572: block:block_rq_insert: 253,1 W 0 () 5550 + 8 [fio]
	fio 71005 [000] 977641.575572: block:block_rq_insert: 253,1 W 0 () 5558 + 255 [fio]
	fio 71005 [000] 977641.575573: block:block_rq_insert: 253,1 W 0 () 5813 + 255 [fio]
	fio 71005 [000] 977641.575574: block:block_rq_insert: 253,1 W 0 () 6068 + 255 [fio]
	fio 71005 [000] 977641.575574: block:block_rq_insert: 253,1 W 0 () 6323 + 255 [fio]
	fio 71005 [000] 977641.575575: block:block_rq_insert: 253,1 W 0 () 6578 + 255 [fio]
	fio 71005 [000] 977641.575576: block:block_rq_insert: 253,1 W 0 () 6833 + 255 [fio]
	fio 71005 [000] 977641.575577: block:block_rq_insert: 253,1 W 0 () 7088 + 255 [fio]
	fio 71005 [000] 977641.575779: block:block_rq_insert: 253,1 W 0 () 7343 + 255 [fio]
	fio 71005 [000] 977641.575781: block:block_rq_insert: 253,1 W 0 () 7598 + 8 [fio]
	fio 71005 [000] 977641.577234: block:block_rq_insert: 253,1 W 0 () 3510 + 255 [fio]
	fio 71005 [000] 977641.577236: block:block_rq_insert: 253,1 W 0 () 3765 + 255 [fio]

[bitesize-nd.stp](https://sourceware.org/systemtap/examples/lwtools/bitesize-nd.stp) 是 Systemtap 写的统计块 IO 的字节数大小分布的工具。
基于该工具，简单修改后，即可按照 Block IO 请求扇区数来统计，请参考 [bio_sectors.stp](https://github.com/yangoliver/mytools/blob/master/debug/systemtap/bio_sectors.stp) 的源码。

	$ sudo ./bio_sectors.stp
	Tracing block I/O... Hit Ctrl-C to end.
	^C
	I/O size (sectors):

	[...snipped...]

	process name: fio
	value |-------------------------------------------------- count
	    0 |                                                       0
	    1 |                                                      17
	    2 |                                                      26
	    4 |                                                      63
	    8 |@@@                                                 2807
	   16 |                                                     398
	   32 |                                                     661
	   64 |@@                                                  1625
	  128 |@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@  38490
	  256 |                                                       0
	  512 |                                                       0

可以看到，128 ~ 255 扇区的分布占了绝大多数，本例中，实际上这个区间的 IO 请求都是 255 个扇区，与之前 perf 查看的结果一致。

### 3.2 写延迟分析

[iosnoop](https://github.com/brendangregg/perf-tools/blob/master/iosnoop) 不但可以了解块设备上的 IO 请求大小，更有从 IO 请求发起到完成的延迟时间的信息。
下面我们在运行 `fio` 测试时，使用 `iosnoop` 来获得的相关信息。

首先，我们需要得到 `fio` 测试所用的块设备的主次设备号，

	$ mount | grep sample
	/dev/sampleblk1 on /mnt type ext4 (rw,relatime,seclabel,data=ordered)
	[yango@localhost ~]$ ls -l /dev/sampleblk1
	brw-rw----. 1 root disk 253, 1 Aug 12 22:10 /dev/sampleblk1

然后，运行 `iosnoop` 来获取所有在 `/dev/sampleblk1` 上的 IO 请求，

	$ sudo iosnoop -d 253,1 -s -t
	Tracing block I/O. Ctrl-C to end
	STARTs          ENDs            COMM         PID    TYPE DEV      BLOCK        BYTES     LATms
	11165.028153    11165.028194    fio          11425  W    253,1    4534         130560     0.04
	11165.028196    11165.028210    fio          11425  W    253,1    4789         130560     0.01
	11165.028211    11165.028224    fio          11425  W    253,1    5044         130560     0.01
	11165.028227    11165.028241    fio          11425  W    253,1    5299         130560     0.01
	11165.028244    11165.028258    fio          11425  W    253,1    5554         130560     0.01
	11165.028261    11165.028274    fio          11425  W    253,1    5809         130560     0.01
	11165.028276    11165.028290    fio          11425  W    253,1    6064         130560     0.01
	11165.028295    11165.028309    fio          11425  W    253,1    6319         130560     0.01
	11165.028311    11165.028312    fio          11425  W    253,1    6574         4096       0.00
	11165.029896    11165.029937    fio          11425  W    253,1    2486         130560     0.04
	11165.029939    11165.029951    fio          11425  W    253,1    2741         130560     0.01
	11165.029952    11165.029965    fio          11425  W    253,1    2996         130560     0.01
	11165.029968    11165.029981    fio          11425  W    253,1    3251         130560     0.01
	11165.029982    11165.029995    fio          11425  W    253,1    3506         130560     0.01
	11165.029998    11165.030012    fio          11425  W    253,1    3761         130560     0.01
	11165.030012    11165.030026    fio          11425  W    253,1    4016         130560     0.01
	11165.030029    11165.030042    fio          11425  W    253,1    4271         130560     0.01
	11165.030044    11165.030045    fio          11425  W    253,1    4526         4096       0.00
	11165.030095    11165.030135    fio          11425  W    253,1    4534         130560     0.04

可以看到，该输出不但包含了 IO 请求的大小，而且还有 IO 延迟时间。如，130560 字节正好就是 255 扇区，4096 字节，恰好就是 8 个扇区。因此，IO 大小和之前其它工具得到时类似的。
而在发出 255 扇区的 IO 请求延迟是有变化的，大致是 0.01 毫秒或者 0.04 毫秒，大概是百纳秒级别的延迟。

`iosnoop` 在短时间内会产生大量的输出，每个 IO 请求的 IO 延迟时间都可能有很大差异，如何能对 `fio` 测试的延迟有没有更好的数据呈现方式呢？

[Heatmap](https://github.com/brendangregg/HeatMap) 就是一个这样的工具，其具体使用方法如下，

	$ sudo ./iosnoop -d 253,1 -s -t >  iosnoop.log
	$ grep '^[0-9]'  iosnoop.log | awk '{ print $1, $9 }' | sed  's/\.//g' | sed 's/$/0/g' > trace.txt
	$ ./trace2heatmap.pl --unitstime=us --unitslatency=us --maxlat=200 --grid trace.txt> heatmap.svg

于是，基于 `iosnoop` 工具得到的数据，我们生成了下面的热点图 (Heatmap)，

<img src="/media/images/2016/heatmap_latency_iosnoop_fs_seq_write_sync_001.svg" width="100%" height="100%" />

右击该图片，在新窗口打开，在图片范围内移动鼠标，即可看到不同的延迟时间所占 IO 请求数据采样的百分比。
例如，颜色最红的那一行代表采样最多的 IO 延迟，在横轴时间是 40 秒时，延迟范围大概是 8 ~ 12 微妙，具有这样延迟的 IO 请求站了全部采样的 76%。

### 3.3 文件和块 IO 延迟的比较

在 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中，我们介绍过 `fio` 的输出中自带 IO 延迟的计算和数值分布的统计。
例如，下面的输出就是这个 `fio` 测试的一个结果，

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

> 如果仔细分析上面的结果，可以发现，其中 clat 和 lat 的分布要明显好于 iosnoop 的结果。这是为什么呢？

其实这很好解释：因为 `fio` 的 clat 和 lat 是文件同步 IO 的延迟，该 IO 模式是 buffer IO，即文件的读写是基于文件的 page cache 的，是内存的读写。因此 clat 和 lat 的延迟要小很多。

而本章中，`iosnoop` 的 IO 延迟是块 IO 的延迟。文件系统 buffer IO 的读写并不会直接触发块设备的读写，因此，`iosnoop` 的 IO 请求和 `fio` 的 IO 请求根本不是同一个 IO 请求。

如果还记得 [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3) 里的分析，我们知道,
这里的 `iosnoop` 的 IO 请求，都是 `fio` 通过调用 fadvise64，使用 POSIX_FADV_DONTNEED 把 /mnt/test 在 page cache 里的数据 flush 到磁盘引发的。

### 3.4 块 IO 吞吐量和 IOPS

运行 `fio` 测试时，我们可以利用 [iostat(1)](https://linux.die.net/man/1/iostat) 命令来获取指定块设备在测试中的吞吐量 (throughput) 和 IOPS。

	$ iostat /dev/sampleblk1  -xmdz 1
	Linux 4.6.0-rc3+ (localhost.localdomain) 	08/25/2016 	_x86_64_	(2 CPU)

	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00     0.37    0.00   59.13     0.00     6.50   225.31     0.01    0.15    0.00    0.15   0.02   0.12

	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00   168.00    0.00 8501.00     0.00   932.89   224.74     0.77    0.10    0.00    0.10   0.02  14.40

	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00    63.00    0.00 8352.00     0.00   909.64   223.05     0.89    0.11    0.00    0.11   0.02  16.30

	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00    59.00    0.00 8305.00     0.00   908.45   224.02     0.98    0.13    0.00    0.13   0.02  17.50

	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00    36.00    0.00 8536.00     0.00   936.51   224.69     1.06    0.13    0.00    0.13   0.02  19.00

	[...snipped...]

其中，rMB/s 和 wMB/s 就是读写的吞吐量，而 r/s 和 w/s 就是 IOPS。
本例中，sampleblk1 块设备的吞吐量是 908 ～ 932 MB/s，IOPS 大概在 8300 ~ 8500。

需要说明的是，此处的的吞吐量和 IOPS 与如下所示的 `fio` 返回的输出里的有很大不同，

	write: io=1134.8GB, bw=1038.2MB/s, iops=265983, runt=1118309msec

本例的测试中，`fio` 返回的是应用程序的 IO 吞吐量和 IOPS，而 `iostat` 返回的是底层一个块设备层面的吞吐量和 IOPS。

## 4. 小结

本文通过使用 Linux 下的各种追踪工具 Systemtap，Perf，`iosnoop` (基于 ftrace 和 tracepoint)，及 `iostat` 来分析 fio 测试时，底层块设备的运行情况。
我们掌握了本文中块设备 IO 在 fio  测试的主要特征，块 IO size，IO 延迟分布。这是性能分析里 resource analysis 方法的一部分。

关于 Linux 动态追踪工具的更多信息，请参考延伸阅读章节里的链接。

## 5. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2)
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3)
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
