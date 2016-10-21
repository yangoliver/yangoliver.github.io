---
layout: post
title: Linux Block Driver - 4
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

>处于草稿状态，在完成前还会有大量修改。
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
并且，给出了设备主次号，相关操作，及起始扇区和扇区数，

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

可以看到，128 ~ 255 扇区的分布占了绝大多数，本例中，其实具体是这个区间的 255 扇区的数目，与之前 perf 查看的结果类似。

### 3.2 写延迟分析


## 4. 实验

TBD

## 5. 小结

TBD

## 6. 延伸阅读

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
