---
layout: post
title: Linux Block Driver - 7
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, perf, crash, trace, file system, kernel, linux, storage]
---

>本文处于草稿状态，内容可能随时更改。转载时请包含原文或者作者网站链接：<http://oliveryang.net>

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
* [Linux Block Driver - 6](http://oliveryang.net/2016/11/linux-block-driver-basic-6) 里，我们解决了 BIO 拆分的问题，进一步理解了吞吐，延迟和 IOPS 的关系。

本文将继续之前的实验，围绕这个简单的 `fio` 测试，探究 Linux 块设备驱动的运作机制。除非特别指明，本文中所有 Linux 内核源码引用都基于 4.6.0。其它内核版本可能会有较大差异。

## 2. 准备

阅读本文前，可能需要如下准备工作，

- 参考 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中的内容，加载该驱动，格式化设备，装载 Ext4 文件系统。
- 按照 [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2) 中的步骤，运行 `fio` 测试。
- 按照 [Linux Block Driver - 5](http://oliveryang.net/2016/10/linux-block-driver-basic-5) 中的内容，使用 `blktrace` 和 `blkparse` 跟踪 IO 操作，并尝试解释跟踪结果。

本文将在与前文完全相同 `fio` 测试负载下，使用 `blktrace` 在块设备层面对该测试做进一步的分析。

## 3. IO 调度器基本原理

## 4. 实验

## 5. 小结

## 6. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2)
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3)
* [Linux Block Driver - 4](http://oliveryang.net/2016/08/linux-block-driver-basic-4)
* [Linux Block Driver - 5](http://oliveryang.net/2016/10/linux-block-driver-basic-5)
* [Linux Block Driver - 6](http://oliveryang.net/2016/11/linux-block-driver-basic-6)
* [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/)
* [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Explicit block device plugging](https://lwn.net/Articles/438256)
