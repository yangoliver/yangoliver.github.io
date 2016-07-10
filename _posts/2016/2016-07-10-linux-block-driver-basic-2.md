---
layout: post
title: Linux Block Driver - 2
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, crash, kernel, linux, storage]
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

## 3. 实验

## 4. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Device Drivers, Third Edition](http://lwn.net/Kernel/LDD3)
