---
layout: post
title: Linux Block Driver - 6
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

>本文尚未完成，内容变动频繁，请转载。转载时请包含原文或者作者网站链接：<http://oliveryang.net>

* content
{:toc}

## 1. 背景

本系列文章整体脉络回顾，

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 介绍了一个只有 200 行源码的 Sampleblk 块驱动的实现。
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中，在 Sampleblk 驱动创建了 Ext4 文件系统，并做了一个 `fio` 顺序写测试。
  测试中我们利用 Linux 的各种跟踪工具，对这个 `fio` 测试做了一个性能个性化分析。
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3) 中，利用 Linux 跟踪工具和 Flamegraph 来对文件系统层面上的文件 IO 内部实现，有了一个概括性的了解。
* [Linux Block Driver - 4](http://oliveryang.net/2016/08/linux-block-driver-basic-4) 里，在之前同样的 `fio` 顺序写测试下，分析 Sampleblk 块设备的 IO 性能特征，大小，延迟，统计分布，IOPS，吞吐等。
* [Linux Block Driver - 5](http://oliveryang.net/2016/10/linux-block-driver-basic-5) 中，使用 `blktrace` 跟踪了 `fio` 顺序写测试的 IO 操作，并对跟踪结果和 IO 流程做了详细总结。

本文将继续之前的实验，围绕这个简单的 `fio` 测试，探究 Linux 块设备驱动的运作机制。除非特别指明，本文中所有 Linux 内核源码引用都基于 4.6.0。其它内核版本可能会有较大差异。

## 2. 准备

阅读本文前，可能需要如下准备工作，

- 参考 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中的内容，加载该驱动，格式化设备，装载 Ext4 文件系统。
- 按照 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中的步骤，运行 `fio` 测试。
- 按照 [Linux Block Driver - 5](http://oliveryang.net/2016/10/linux-block-driver-basic-5) 中的内容，使用 `blktrace` 和 `blkparse` 跟踪 IO 操作，并尝试解释跟踪结果。

本文将在与前文完全相同 `fio` 测试负载下，使用 `blktrace` 在块设备层面对该测试做进一步的分析。

## 3. bio 拆分问题

在 [Linux Block Driver - 5](http://oliveryang.net/2016/10/linux-block-driver-basic-5) 中，我们发现，每次 IO，在块设备层都会经历一次 bio 拆分操作。

	$ blkparse sampleblk1.blktrace.0   | grep 2488 | head -n6
	253,1    0        1     0.000000000 76455  Q   W 2488 + 2048 [fio]
	253,1    0        2     0.000001750 76455  X   W 2488 / 2743 [fio] >>> 拆分
	253,1    0        4     0.000003147 76455  G   W 2488 + 255 [fio]
	253,1    0       53     0.000072101 76455  I   W 2488 + 255 [fio]
	253,1    0       70     0.000075621 76455  D   W 2488 + 255 [fio]
	253,1    0       71     0.000091017 76455  C   W 2488 + 255 [0]

而我们知道，IO 拆分操作对块设备性能是有负面的影响的。那么，为什么会出现这样的问题？我们应当如何避免这个问题？

### 3.1 原因分析

当文件系统提交 `bio` 时，`generic_make_request` 会调用 `blk_queue_bio` 将 `bio` 缓存到设备请求队列 (request_queue) 里。
而在缓存 `bio` 之前，`blk_queue_bio` 会调用 `blk_queue_split`，此函数根据块设备的请求队列设置的 `limits.max_sectors` 和 `limits.max_segments` 属性，来对超出自己处理能力的大 `bio` 进行拆分。

X 操作对应的具体代码路径，请参考 [perf 命令对 block:block_split 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_split.log)。

那么，本例中的 sampleblk 驱动的块设备，是否设置了 `request_queue` 的相关属性呢？我们可以利用 `crash` 命令，查看该设备驱动的 `request_queue` 及其属性，

	crash7> dev -d
	MAJOR GENDISK            NAME       REQUEST_QUEUE      TOTAL ASYNC  SYNC   DRV
	    8 ffff88003505f000   sda        ffff880034e34800       0     0     0     0
	   11 ffff88003505e000   sr0        ffff880034e37500       0     0     0     0
	   11 ffff880035290800   sr1        ffff880034e36c00       0     0     0     0
	  253 ffff88003669b800   sampleblk1 ffff880034e30000       0     0     0     0  >>> sampleblk 驱动对应的块设备

	crash7> request_queue.limits ffff880034e30000
	  limits = {
	    bounce_pfn = 4503599627370495,
	    seg_boundary_mask = 4294967295,
	    virt_boundary_mask = 0,
	    max_hw_sectors = 255,
	    max_dev_sectors = 0,
	    chunk_sectors = 0,
	    max_sectors = 255,				>>> Split bio 的原因
	    max_segment_size = 65536,
	    physical_block_size = 512,
	    alignment_offset = 0,
	    io_min = 512,
	    io_opt = 0,
	    max_discard_sectors = 0,
	    max_hw_discard_sectors = 0,
	    max_write_same_sectors = 0,
	    discard_granularity = 0,
	    discard_alignment = 0,
	    logical_block_size = 512,
	    max_segments = 128,             >>> Split bio 的又一原因
	    max_integrity_segments = 0,
	    misaligned = 0 '\000',
	    discard_misaligned = 0 '\000',
	    cluster = 1 '\001',
	    discard_zeroes_data = 0 '\000',
	    raid_partial_stripes_expensive = 0 '\000'
	  }

而这里请求队列的 `limits.max_sectors` 和 `limits.max_segments` 属性，则是由块设备驱动程序在初始化时，根据自己的处理能力设置的。

那么 sampleblk 是如何初始化 request_queue 的呢？

在 sampleblk 驱动的代码里，我们只找到如下函数，

	static int sampleblk_alloc(int minor)
	{

	[...snipped...]

	    spin_lock_init(&sampleblk_dev->lock);
	    sampleblk_dev->queue = blk_init_queue(sampleblk_request,
	        &sampleblk_dev->lock);

	[...snipped...]

而进一步研究 `blk_init_queue` 的实现，我们就发现，这个 `limits.max_sectors` 的限制，正好就是调用 `blk_init_queue` 引起的，

	blk_init_queue->blk_init_queue_node->blk_init_allocated_queue->blk_queue_make_request->blk_set_default_limits

调用 `blk_init_queue` 会最终导致 `blk_set_default_limits` 将系统定义的默认限制参数设置到 `request_queue` 上，

	include/linux/blkdev.h

	enum blk_default_limits {
	    BLK_MAX_SEGMENTS    = 128,
	    BLK_SAFE_MAX_SECTORS    = 255, >>> sampleblk 使用的初值
	    BLK_DEF_MAX_SECTORS = 2560,
	    BLK_MAX_SEGMENT_SIZE    = 65536,
	    BLK_SEG_BOUNDARY_MASK   = 0xFFFFFFFFUL,
	};

由于 sampleblk 设备是基于内存的块设备，并不存在一般块设备硬件的限制，故此，我们可以通过调用 `blk_set_stacking_limits` 解除 Linux IO 栈的诸多限制。

具体改动可以参考 [lktm 里 sampleblk 的改动](https://github.com/yangoliver/lktm/commit/bc05891d53334cc3fa4690b87718c935ba76f52b#diff-3858c6a043ac372fbae32d03d9f26d16).

经过驱动的重新编译、加载、文件系统格式化，装载，可以查看 sampleblk 驱动的 `request_queue` 确认限制已经解除，

	crash7> mod -s sampleblk /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko
	     MODULE       NAME                   SIZE  OBJECT FILE
	ffffffffa0068580  sampleblk              2681  /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko
	crash7> dev -d
	MAJOR GENDISK            NAME       REQUEST_QUEUE      TOTAL ASYNC  SYNC   DRV
	   11 ffff88003501b800   sr0        ffff8800338b0000       0     0     0     0
	    8 ffff88003501e000   sda        ffff880034a8c800       0     0     0     0
	    8 ffff88003501f000   sdb        ffff880034a8da00       0     0     0     0
	   11 ffff88003501d800   sr1        ffff8800338b0900       0     0     0     0
	  253 ffff880033867800   sampleblk1 ffff8800338b2400       0     0     0     0
	crash7> request_queue.limits -x ffff8800338b2400
	  limits = {
	    bounce_pfn = 0xfffffffffffff,
	    seg_boundary_mask = 0xffffffff,
	    virt_boundary_mask = 0x0,
	    max_hw_sectors = 0xffffffff,
	    max_dev_sectors = 0xffffffff,  >>> 最大值，原来是 255
	    chunk_sectors = 0x0,
	    max_sectors = 0xffffffff,
	    max_segment_size = 0xffffffff,
	    physical_block_size = 0x200,
	    alignment_offset = 0x0,
	    io_min = 0x200,
	    io_opt = 0x0,
	    max_discard_sectors = 0x0,
	    max_hw_discard_sectors = 0x0,
	    max_write_same_sectors = 0xffffffff,
	    discard_granularity = 0x0,
	    discard_alignment = 0x0,
	    logical_block_size = 0x200,
	    max_segments = 0xffff,   >>> 最大值，原来是 128
	    max_integrity_segments = 0x0,
	    misaligned = 0x0,
	    discard_misaligned = 0x0,
	    cluster = 0x1,
	    discard_zeroes_data = 0x1,
	    raid_partial_stripes_expensive = 0x0
	  }

运行与之前系列文章中相同的 `fio` 测试，同时用 `blktrace` 跟踪 IO 操作，

	$ sudo blktrace /dev/sampleblk1

可以看到，此时已经没有 bio 拆分操作，即 X action,

	$ blkparse sampleblk1.blktrace.0 | grep X | wc -l
	0

如果查看 IO 完成的操作，可以看到，文件系统的 page cache 4K 大小的页面可以在一个块 IO 操作完成，也可以分多次完成，如下例中 2 次和 3 次，

	$ blkparse sampleblk1.blktrace.0 | grep C | head -10
	253,1    0        9     0.000339563 128937  C   W 2486 + 4096 [0]
	253,1    0       18     0.002813922 128937  C   W 2486 + 4096 [0]
	253,1    1        9     0.006499452 128938  C   W 4966 + 1616 [0]
	253,1    0       27     0.006674160 128924  C   W 2486 + 2256 [0]
	253,1    0       34     0.006857810 128937  C   W 4742 + 224 [0]
	253,1    1       19     0.009835686 128938  C   W 2486 + 1736 [0]
	253,1    1       21     0.010198002 128938  C   W 4222 + 2360 [0]
	253,1    0       45     0.012429598 128937  C   W 2486 + 4096 [0]
	253,1    0       54     0.015565043 128937  C   W 2486 + 4096 [0]
	253,1    0       63     0.017418088 128937  C   W 2486 + 4096 [0]

但如果查看 [Linux Block Driver - 5](http://oliveryang.net/2016/10/linux-block-driver-basic-5) 的结果，则一个页面的写要固定被拆分成 20 次 IO 操作。

用 `iostat` 查看块设备的性能，我们可以发现，设备的 IO 吞吐量比 [Linux Block Driver - 4](http://oliveryang.net/2016/08/linux-block-driver-basic-4) 提高了 10% ～ 15%。
原来版本驱动 900 多 MB/s 的吞吐量提升到了 1000 多 MB/s。 但另一翻边，IOPS 从原有的 8000 多降到了 700 多，整整差了 10 倍。

	$ iostat /dev/sampleblk1  -xmdz 1
	
	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00   558.42    0.00  761.39     0.00  1088.20  2927.08     0.22    0.29    0.00    0.29   0.27  20.79
	
	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00   542.00    0.00  768.00     0.00  1097.41  2926.44     0.20    0.26    0.00    0.26   0.25  19.20
	
	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00   524.00    0.00  799.00     0.00  1065.24  2730.43     0.21    0.26    0.00    0.26   0.25  20.00
	
	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00   846.00    0.00  742.00     0.00  1079.73  2980.17     0.20    0.27    0.00    0.27   0.26  19.60
	
	Device:         rrqm/s   wrqm/s     r/s     w/s    rMB/s    wMB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
	sampleblk1        0.00   566.00    0.00  798.00     0.00  1068.08  2741.14     0.21    0.26    0.00    0.26   0.26  20.50

### 3.2 问题解决

TBD

## 4. 小结

TBD

## 5. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2)
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3)
* [Linux Block Driver - 4](http://oliveryang.net/2016/08/linux-block-driver-basic-4)
* [Linux Block Driver - 5](http://oliveryang.net/2016/10/linux-block-driver-basic-5)
* [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/)
* [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Explicit block device plugging](https://lwn.net/Articles/438256)
