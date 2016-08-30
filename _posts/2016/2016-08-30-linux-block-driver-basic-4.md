---
layout: post
title: Linux Block Driver - 4
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

> 本文处于草稿状态，在完成前还会有大量修改。
> 本文首发于<http://oliveryang.net>，转载时请包含原文或者作者网站链接。

* content
{:toc}

## 1. 背景

让我们梳理一下本系列文章整体脉络。

* 首先，[Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 介绍了一个只有 200 行源码的 Sampleblk 块驱动的实现。
* 然后，在 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中，我们在 Sampleblk 驱动创建了 Ext4 文件系统，并做了一个 fio 顺序写测试。
  测试中我们利用 Linux 的各种跟踪工具，对这个 fio 测试做了一个性能个性化分析。
* 而在 [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3) 中，我们利用 Linux 跟踪工具和 Flamegraph 来对文件系统层面上的文件 IO 内部实现，有了一个概括性的了解。

本文将继续之前的实验，围绕这个简单的 fio 测试，探究 Linux 块设备驱动的运作机制。除非特别指明，本文中所有 Linux 内核源码引用都基于 4.6.0。其它内核版本可能会有较大差异。

## 2. 准备

阅读本文前，可能需要如下准备工作，

- 了解 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中所提的 fio 测试的环境准备，命令运行，还有性能分析方法。
- 阅读 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中 Sampleblk 驱动的源码，理解其含义。

TBD

## 3. 深入理解 Block IO

TBD

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
