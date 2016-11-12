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

[blktrace(8)](https://linux.die.net/man/8/blktrace) 是非常方便的跟踪块设备 IO 的工具。我们可以利用这个工具来分析前几篇文章中的 `fio` 测试时的块设备 IO 情况。

在 blktrace 的每条记录里，都包含 IO 操作的起始扇区地址。因此，利用该起始扇区地址，可以找到针对这个地址的完整的 IO 操作过程。
前面的例子里，如果我们想找到所有起始扇区为 2488 的 IO 操作，则可以用如下办法，

	$ blkparse sampleblk1.blktrace.0   | grep 2488 | head -n6
	253,1    0        1     0.000000000 76455  Q   W 2488 + 2048 [fio]
	253,1    0        2     0.000001750 76455  X   W 2488 / 2743 [fio]
	253,1    0        4     0.000003147 76455  G   W 2488 + 255 [fio]
	253,1    0       53     0.000072101 76455  I   W 2488 + 255 [fio]
	253,1    0       70     0.000075621 76455  D   W 2488 + 255 [fio]
	253,1    0       71     0.000091017 76455  C   W 2488 + 255 [0]

可以直观的看出，这个 `fio` 测试对起始扇区 2488 发起的 IO 操作经历了以下历程，

	Q -> X -> G -> I -> D -> C

### 3.1 原因分析

文件系统提交 `bio` 时，`generic_make_request` 会调用 `blk_queue_bio` 将 `bio` 缓存到设备请求队列 (request_queue) 里。
而在缓存 `bio` 之前，`blk_queue_bio` 会调用 `blk_queue_split`，此函数根据块设备的请求队列设置的 `limits.max_sectors` 和 `limits.max_segments` 属性，来对超出自己处理能力的大 `bio` 进行拆分。

而这里请求队列的 `limits.max_sectors` 和 `limits.max_segments` 属性，则是由块设备驱动程序在初始化时，根据自己的处理能力设置的。
当 `bio` 拆分频繁发生时，这时 IO 操作的性能会受到影响，因此，`blktrace` 结果中的 X 操作，需要做进一步分析，来搞清楚 Sampleblk 驱动如何设置请求队列属性，进而影响到 `bio` 拆分的。

X 操作对应的具体代码路径，请参考 [perf 命令对 block:block_split 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_split.log)，

	100.00%   100.00%  fio      [kernel.vmlinux]  [k] blk_queue_split
	            |
	            ---blk_queue_split
	               blk_queue_bio
	               generic_make_request
	               submit_bio
	               ext4_io_submit
	               |
	               |--55.73%-- ext4_writepages
	               |          do_writepages
	               |          __filemap_fdatawrite_range
	               |          sys_fadvise64
	               |          do_syscall_64
	               |          return_from_SYSCALL_64
	               |          posix_fadvise64
	               |          0
	               |
	                --44.27%-- ext4_bio_write_page
	                          mpage_submit_page
	                          mpage_process_page_bufs
	                          mpage_prepare_extent_to_map
	                          ext4_writepages
	                          do_writepages
	                          __filemap_fdatawrite_range
	                          sys_fadvise64
	                          do_syscall_64
	                          return_from_SYSCALL_64
	                          posix_fadvise64
	                          0

### 3.2 问题解决

TBD

## 4. 小结

TBD

## 5. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2)
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3)
* [Linux Block Driver - 4](http://oliveryang.net/2016/08/linux-block-driver-basic-4)
* [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/)
* [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Explicit block device plugging](https://lwn.net/Articles/438256)
