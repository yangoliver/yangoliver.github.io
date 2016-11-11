---
layout: post
title: Linux Block Driver - 5
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

>转载时请包含原文或者作者网站链接：<http://oliveryang.net>


* content
{:toc}

## 1. 背景

本系列文章整体脉络回顾，

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 介绍了一个只有 200 行源码的 Sampleblk 块驱动的实现。
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中，在 Sampleblk 驱动创建了 Ext4 文件系统，并做了一个 `fio` 顺序写测试。
  测试中我们利用 Linux 的各种跟踪工具，对这个 `fio` 测试做了一个性能个性化分析。
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3) 中，利用 Linux 跟踪工具和 Flamegraph 来对文件系统层面上的文件 IO 内部实现，有了一个概括性的了解。
* [Linux Block Driver - 4](http://oliveryang.net/2016/08/linux-block-driver-basic-4) 里，在之前同样的 `fio` 顺序写测试下，分析 Sampleblk 块设备的 IO 性能特征，大小，延迟，统计分布，IOPS，吞吐等。

本文将继续之前的实验，围绕这个简单的 `fio` 测试，探究 Linux 块设备驱动的运作机制。除非特别指明，本文中所有 Linux 内核源码引用都基于 4.6.0。其它内核版本可能会有较大差异。

## 2. 准备

阅读本文前，可能需要如下准备工作，

- 参考 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中的内容，加载该驱动，格式化设备，装载 Ext4 文件系统。
- 按照 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中的步骤，运行 `fio` 测试。

本文将在与前文完全相同 `fio` 测试负载下，使用 `blktrace` 在块设备层面对该测试做进一步的分析。

## 3. 使用 blktrace

[blktrace(8)](https://linux.die.net/man/8/blktrace) 是非常方便的跟踪块设备 IO 的工具。我们可以利用这个工具来分析前几篇文章中的 `fio` 测试时的块设备 IO 情况。

首先，在 `fio` 运行时，运行 `blktrace` 来记录指定块设备上的 IO 操作，

	$ sudo blktrace /dev/sampleblk1
	[sudo] password for yango:

	^C=== sampleblk1 ===
	  CPU  0:              1168040 events,    54752 KiB data
	    Total:               1168040 events (dropped 0),    54752 KiB data

退出跟踪后，IO 操作的都被记录在日志文件里。可以使用	[blkparse(1)](https://linux.die.net/man/1/blkparse) 命令来解析和查看这些 IO 操作的记录。
虽然 blkparse(1) 手册给出了每个 IO 操作里的具体跟踪动作 (Trace Action) 字符的含义，但下面的表格，更近一步地包含了下面的信息，

- Trace Action 之间的时间顺序
- 每个 `blkparse` 的 Trace Action 对应的 Linux block tracepoints 的名字，和内核对应的 trace 函数。
- Trace Action 是否对块设备性能有正面或者负面的影响
- Trace Action 的额外说明，这个比 blkparse(1) 手册里的描述更贴近 Linux 实现

|Order|Action|Linux block tracepoints   |Kernel trace function     |Perf impact|Description                                                                                                          |
|-----|------|--------------------------|--------------------------|-----------|---------------------------------------------------------------------------------------------------------------------|
|  1  | Q    |block:block_bio_queue     |trace_block_bio_queue     |Neutral    |Intent to queue a bio on a given reqeust_queue. No real requests exists yet.                                         |
|  2  | B    |block:block_bio_bounce    |trace_block_bio_bounce    |Negative   |Pages in bio has copied to bounce buffer to avoid hardware (DMA) limits.                                             |
|  3  | X    |block:block_split         |trace_block_split         |Negative   |Split a bio with smaller pieces due to underlying block device's limits.                                             |
|  4  | M    |block:block_bio_backmerge |trace_block_bio_backmerge |Positive   |A previously inserted request exists that ends on the boundary of where this bio begins, so IO scheduler merges them.|
|  5  | F    |block:block_bio_frontmerge|trace_block_bio_frontmerge|Positive   |Same as the back merge, except this i/o ends where a previously inserted requests starts.                            |
|  6  | S    |block:block_sleeprq       |trace_block_sleeprq       |Negative   |No available request structures were available (eg. memory pressure), so the issuer has to wait for one to be freed. |
|  7  | G    |block:block_getrq         |trace_block_getrq         |Neutral    |Allocated a free request struct successfully.                                                                        |
|  8  | P    |block:block_plug          |trace_block_plug          |Positive   |I/O isn't immediately dispatched to request_queue, instead it is held back by current process IO plug list.          |
|  9  | I    |block:block_rq_insert     |trace_block_rq_insert     |Neutral    |A request is sent to the IO scheduler internal queue and later service by the driver.                                |
|  10 | U    |block:block_unplug        |trace_block_unplug        |Positive   |Flush queued IO request to device request_queue, could be triggered by timeout or intentionally function call.       |
|  11 | A    |block:block_rq_remap      |trace_block_rq_remap      |Neutral    |Only used by stackable devices, for example, DM(Device Mapper) and raid driver.                                      |
|  12 | D    |block:block_rq_issue      |trace_block_rq_issue      |Neutral    |Device driver code is picking up the request                                                                         |
|  13 | C    |block:block_rq_complete   |trace_block_rq_complete   |Neutral    |A previously issued request has been completed. The output will detail the sector and size of that request.          |

如下例，我们可以利用 grep 命令，过滤 `blkparse` 解析出来的所有有关 IO 完成动作 (C Action) 的 IO 记录，

	$ blkparse sampleblk1.blktrace.0   | grep C | head -n20
	253,1    0       71     0.000091017 76455  C   W 2488 + 255 [0]
	253,1    0       73     0.000108071 76455  C   W 2743 + 255 [0]
	253,1    0       75     0.000123489 76455  C   W 2998 + 255 [0]
	253,1    0       77     0.000139005 76455  C   W 3253 + 255 [0]
	253,1    0       79     0.000154437 76455  C   W 3508 + 255 [0]
	253,1    0       81     0.000169913 76455  C   W 3763 + 255 [0]
	253,1    0       83     0.000185682 76455  C   W 4018 + 255 [0]
	253,1    0       85     0.000201777 76455  C   W 4273 + 255 [0]
	253,1    0       87     0.000202998 76455  C   W 4528 + 8 [0]
	253,1    0       89     0.000267387 76455  C   W 4536 + 255 [0]
	253,1    0       91     0.000283523 76455  C   W 4791 + 255 [0]
	253,1    0       93     0.000299077 76455  C   W 5046 + 255 [0]
	253,1    0       95     0.000314889 76455  C   W 5301 + 255 [0]
	253,1    0       97     0.000330389 76455  C   W 5556 + 255 [0]
	253,1    0       99     0.000345746 76455  C   W 5811 + 255 [0]
	253,1    0      101     0.000361125 76455  C   W 6066 + 255 [0]
	253,1    0      108     0.000378428 76455  C   W 6321 + 255 [0]
	253,1    0      110     0.000379581 76455  C   W 6576 + 8 [0]

例如，上面的输出中，第一条记录的含义是，

> 它是序号为 71 的 IO 完成 (C) 操作。是进程号为 76455 的进程，在 CPU 0，对主次设备号 253,1 的块设备，发起的起始地址为 2488，长度为 255 个扇区的写 (W) 操作。
> 该 IO 完成 （C）时被记录，当时的时间戳是 0.000091017，是精确到纳秒级的时间戳。利用 IO 操作的时间戳，我们就可以计算两个 IO 操作之间的具体延迟数据。

上面的例子中，可以看到，前 20 条跟踪记录，恰好是一共 4096 字节的数据。本文中 `fio` 测试是 buffer IO 测试，因此，块 IO 是出现在 `fadvise64` 使用 POSIX_FADV_DONTNEED 来 flush 文件系统页缓存时的。
这时，文件系统对块设备发送的 IO 是基于 4K 页面的大小。而这些 4K 的页面，在块设备层被拆分成如上 20 个更小的块 IO 请求来发送。

## 4. IO 流程分析

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

如果对照前面的 blkparse(1) 的 Trace Action 的说明表格，我们就可以很容易理解，内核在块设备层对该起始扇区做的所有 IO 操作的时序。

下面，就针对同一个起始扇区号为 2488 的 IO 操作所经历的历程，对 Linux 块 IO 流程做简要说明。

### 4.1 Q - bio 排队

本文中的 `fio` 测试程序由于是同步的 buffer IO 的写入，因此，在 `write` 系统调用返回时，`fio` 的数据其实并没有真正写在块设备上，而是写到了文件系统的 page cache 里。
如前面几篇文章所述，最终的块设备的 IO 触发，是由 `fadvise64` flush 脏的 page cache 引起的。

因此，`fadvise64` 的系统调用会调用到 Ext4 文件系统的 page cache 写入函数，然后由 Ext4 将内存页封装成 `bio` 来提交给块设备。
和大多数块设备的提交函数一样，函数的入口是 `submit_bio`，该函数会调用 `generic_make_request`，随后代码进入到 `generic_make_request_checks` 对 `bio` 进行检查。
在该函数结尾，通过了检查后，内核代码调用了 `trace_block_bio_queue` 来报告自己意图将 `bio` 发送到设备的队列里。
需要注意的是，此时，`bio` 只是打算要被插入到队列里，而不是已经放在队列里。而且，这时提交的 `bio` 的 `bio->bi_next` 是 NULL 值，并未形成链表。

Q 操作对应的具体代码路径，请参考 [perf 命令对 block:block_bio_queue 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_bio_queue.log)，

	100.00%   100.00%  fio      [kernel.vmlinux]  [k] generic_make_request_checks
                |
                ---generic_make_request_checks
                   generic_make_request
                   |
                   |--88.24%-- blk_queue_split
                   |          blk_queue_bio
                   |          generic_make_request
                   |          submit_bio
                   |          ext4_io_submit
                   |          |
                   |          |--56.38%-- ext4_writepages
                   |          |          do_writepages
                   |          |          __filemap_fdatawrite_range
                   |          |          sys_fadvise64
                   |          |          do_syscall_64
                   |          |          return_from_SYSCALL_64
                   |          |          posix_fadvise64
                   |          |          0
                   |          |
                   |           --43.62%-- ext4_bio_write_page
                   |                     mpage_submit_page
                   |                     mpage_process_page_bufs
                   |                     mpage_prepare_extent_to_map
                   |                     ext4_writepages
                   |                     do_writepages
                   |                     __filemap_fdatawrite_range
                   |                     sys_fadvise64
                   |                     do_syscall_64
                   |                     return_from_SYSCALL_64
                   |                     posix_fadvise64
                   |                     0
                   |
                    --11.76%-- submit_bio
                              ext4_io_submit
                              |
                              |--58.95%-- ext4_writepages
                              |          do_writepages
                              |          __filemap_fdatawrite_range
                              |          sys_fadvise64
                              |          do_syscall_64
                              |          return_from_SYSCALL_64
                              |          posix_fadvise64
                              |          0
                              |
                               --41.05%-- ext4_bio_write_page
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

### 4.2 X - bio 拆分

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

### 4.3 M - 合并 IO 请求

如前所述，文件系统向通用块层提交 IO 请求时，使用的是 `struct bio` 结构，并且 `bio->bi_next` 是 NULL 值，并未形成链表。
在 `blk_queue_bio` 代码中，这个被提交的 `bio` 的缓存处理存在以下几种情况，

* 如果当前进程 IO 处于 Plug 状态，那么尝试将 `bio` 合并到当前进程的 plugged list 里，即 `current->plug.list` 里。
* 如果当前进程 IO 处于 Unplug 状态，那么尝试利用 IO 调度器的代码找到合适的 IO `request`，并将 `bio` 合并到该 `request` 中。
* 如果无法将 `bio` 合并到已经存在的 IO `request` 结构里，那么就进入到单独为该 `bio` 分配空闲 IO `request` 的逻辑里。

不论是 plugged list 还是 IO scheduler 的 IO 合并，都分为向前合并和向后合并两种情况，

- ELEVATOR_BACK_MERGE 由 `bio_attempt_back_merge` 完成
- ELEVATOR_FRONT_MERGE 由 `bio_attempt_front_merge` 完成

细心的读者会发现，前面 `fio` 测试对起始扇区 2488 发起的下面顺序的 IO 操作里，并未包含 M 操作，

	Q -> X -> G -> I -> D -> C

但是，整个 `fio` 测试过程中，还是有部分 IO 被合并了，因为我们并没有用 `blktrace` 捕捉全部 IO 操作，因此没有跟踪到这些合并操作。
当合并操作发生时，其时序如下，

	Q -> X -> M -> G -> I -> D -> C

如果用 `perf` 命令去跟踪 block:block_bio_backmerge 和 block:block_bio_frontmerge 的事件，会发现都是向后合并操作，测试全程没有向前合并操作。
这是由于本例中的 `fio` 测试是文件顺序写 IO，因此都是向后合并这种情况，所以只有 M 操作，而不会有 F 操作。

M 操作对应的具体代码路径，请参考 [perf 命令对 block:block_bio_backmerge 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_bio_backmerge.log)，

	100.00%   100.00%  fio      [kernel.vmlinux]  [k] bio_attempt_back_merge
                |
                ---bio_attempt_back_merge
                   blk_attempt_plug_merge
                   blk_queue_bio
                   generic_make_request
                   submit_bio
                   ext4_io_submit
                   |
                   |--94.23%-- ext4_writepages
                   |          do_writepages
                   |          __filemap_fdatawrite_range
                   |          sys_fadvise64
                   |          do_syscall_64
                   |          return_from_SYSCALL_64
                   |          posix_fadvise64
                   |          0
                   |
                    --5.77%-- ext4_bio_write_page
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

### 4.4 G - 分配 IO 请求

如前面小结所述，在 `blk_queue_bio` 代码中，若无法合并 `bio` 到已存在的 IO `request` 里， 该函数会为 `bio` 分配一个 IO 请求结构，即 `struct request`。

G 操作对应的具体代码路径，请参考 [perf 命令对 block:block_getrq 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_getrq.log)，

	100.00%   100.00%  fio      [kernel.vmlinux]  [k] get_request
                |
                ---get_request
                   blk_queue_bio
                   generic_make_request
                   submit_bio
                   ext4_io_submit
                   |
                   |--54.41%-- ext4_writepages
                   |          do_writepages
                   |          __filemap_fdatawrite_range
                   |          sys_fadvise64
                   |          do_syscall_64
                   |          return_from_SYSCALL_64
                   |          posix_fadvise64
                   |          0
                   |
                    --45.59%-- ext4_bio_write_page
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

### 4.5 I - 请求插入队列

如前面小结所述，在 `blk_queue_bio` 代码中，当已经为不能合并的 `bio` 分配了 `request`，下一步则有如下两种可能，

* 如果当前进程 IO 已经被 Plug，这个新的 `request` 将会被加到当前进程的 `plug->list` 里来。
* 如果当前进程的 IO 已经或者马上处于 unplug 状态，那么 `request` 将被插入到 IO 调度器的内部队列里。

`blk_queue_bio` 会通过触发 Unplug 操作，最终调用 `__elv_add_request` 函数负责将 `request` 插入到 IO 调度器内部队列，其中牵涉到下面两种情况，

* ELEVATOR_INSERT_SORT_MERGE

  将 `request` 合并到 IO 调度器队列已存在的 `request` 里，并释放新分配的 `request`。

* ELEVATOR_INSERT_SORT

  将 `request` 插入到 IO 调度器经过排序的队列里。例如，将 `request` 插入到 deadline 调度器排序过的红黑树里。

I 操作对应的具体代码路径，请参考 [perf 命令对 block:block_rq_insert 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_rq_insert.log)，

	100.00%   100.00%  fio      [kernel.vmlinux]  [k] __elv_add_request
                |
                ---__elv_add_request
                   blk_flush_plug_list
                   |
                   |--74.74%-- blk_queue_bio
                   |          generic_make_request
                   |          submit_bio
                   |          ext4_io_submit
                   |          ext4_writepages
                   |          do_writepages
                   |          __filemap_fdatawrite_range
                   |          sys_fadvise64
                   |          do_syscall_64
                   |          return_from_SYSCALL_64
                   |          posix_fadvise64
                   |          0
                   |
                    --25.26%-- blk_finish_plug
                              ext4_writepages
                              do_writepages
                              __filemap_fdatawrite_range
                              sys_fadvise64
                              do_syscall_64
                              return_from_SYSCALL_64
                              posix_fadvise64
                              0


### 4.6 D - 发起 IO 请求

有两种常见的触发 Unplug IO 的时机，

* 文件系统通过调用 `blk_finish_plug` 显式地触发
* 当 `blk_queue_bio` 检测到当前进程 `plug->list` 的请求数目超过了 BLK_MAX_REQUEST_COUNT

当 Unplug 发生时，`__blk_run_queue` 最终会被调用，然后块驱动程序的策略函数就会被调用，进而进入块设备 IO 流程。本例中，sampleblk 驱动的策略函数 `sampleblk_request` 开始被调用，

D 操作对应的具体代码路径，请参考 [perf 命令对 block:block_rq_issue 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_rq_issue.log)，

	100.00%   100.00%  fio      [kernel.vmlinux]  [k] blk_peek_request
                |
                ---blk_peek_request
                   blk_fetch_request
                   sampleblk_request
                   __blk_run_queue
                   queue_unplugged
                   blk_flush_plug_list
                   |
                   |--72.41%-- blk_queue_bio
                   |          generic_make_request
                   |          submit_bio
                   |          ext4_io_submit
                   |          ext4_writepages
                   |          do_writepages
                   |          __filemap_fdatawrite_range
                   |          sys_fadvise64
                   |          do_syscall_64
                   |          return_from_SYSCALL_64
                   |          posix_fadvise64
                   |          0
                   |
                    --27.59%-- blk_finish_plug
                              ext4_writepages
                              do_writepages
                              __filemap_fdatawrite_range
                              sys_fadvise64
                              do_syscall_64
                              return_from_SYSCALL_64
                              posix_fadvise64
                              0

### 4.7 C - bio 完成

块驱动在处理完 IO 请求后，可以通过调用 `blk_end_request_all` 来通知通用块层 IO 操作完成。

通知通用块层完成的函数还有 `blk_end_request`。两者的区别主要是，`blk_end_request` 是为 partial complete 设计实现的，但是`blk_end_request_all` 缺省就是完整的 `bio` 完成来设计的。
因此，调用 `blk_end_request` 时，需要指定 IO 操作完成的字节数。因此，如果块设备驱动支持 IO 部分完成特性，则可以使用 `blk_end_request` 来支持。

此外，还存在 `__blk_end_request_all` 和 `__blk_end_request` 形式的 IO 完成通知函数。这两个函数必须在获取 `request_queue` 队列的锁以后才开始调用。
而 `blk_end_request_all` 和 `blk_end_request` 则不需要拿队列锁。

C 操作对应的具体代码路径，请参考 [perf 命令对 block:block_rq_complete 的跟踪结果](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab2/perf_block_rq_complete.log),

	100.00%   100.00%  fio      [kernel.vmlinux]    [k] blk_update_request
                |
                ---blk_update_request
                   |
                   |--99.99%-- blk_update_bidi_request
                   |          blk_end_bidi_request
                   |          blk_end_request_all
                   |          sampleblk_request
                   |          __blk_run_queue
                   |          queue_unplugged
                   |          blk_flush_plug_list
                   |          |
                   |          |--76.92%-- blk_queue_bio
                   |          |          generic_make_request
                   |          |          submit_bio
                   |          |          ext4_io_submit
                   |          |          ext4_writepages
                   |          |          do_writepages
                   |          |          __filemap_fdatawrite_range
                   |          |          sys_fadvise64
                   |          |          do_syscall_64
                   |          |          return_from_SYSCALL_64
                   |          |          posix_fadvise64
                   |          |          0
                   |          |
                   |           --23.08%-- blk_finish_plug
                   |                     ext4_writepages
                   |                     do_writepages
                   |                     __filemap_fdatawrite_range
                   |                     sys_fadvise64
                   |                     do_syscall_64
                   |                     return_from_SYSCALL_64
                   |                     posix_fadvise64
                   |                     0
                    --0.01%-- [...]

## 5. 小结

本文在与前几篇文章相同的 `fio` 测试过程中，使用 `blktrace` 和 `perf` 追踪的块设备层的 IO 操作，解释了 Linux 内核块设备 IO 的基本流程。
第三小节中的 blkparse(1) trace action 的表格对理解 `blktrace` 的输出含义也做了简单的总结，有助于熟悉 `blktrace` 的使用和结果分析。

## 6. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2)
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3)
* [Linux Block Driver - 4](http://oliveryang.net/2016/08/linux-block-driver-basic-4)
* [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/)
* [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Explicit block device plugging](https://lwn.net/Articles/438256)
