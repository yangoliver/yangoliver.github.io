---
layout: post
title: Linux Block Driver Basic - 1
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, kgdb, crash, kernel, linux, storage]
---

>本文首发于<http://oliveryang.net>，转载时请包含原文或者作者网站链接。

> 注意: 本文仍处于构思和写作中。内容随时可能会变动或修改。

## 最简块设备驱动的开发

### 1. 背景

Sampleblk 是一个用于学习目的的 Linux 块设备驱动项目。其中 [day1](https://github.com/yangoliver/lktm/tree/master/drivers/block/sampleblk/day1) 的源代码实现了一个最简的块设备驱动，源代码只有 200 多行。
本文主要围绕这些源代码，讨论 Linux 块设备驱动开发的基本知识。

开发 Linux 驱动需要做一系列的开发环境准备工作。Sampleblk 驱动是在 Linux 4.6.0 下开发和调试的。由于在不同 Linux 内核版本的通用 block 层的 API 有很大变化，这个驱动在其它内核版本编译可能会有问题。
开发，编译，调试内核模块需要先准备内核开发环境，编译内核源代码。这些基础的内容互联网上随处可得，本文不再赘述。

此外，开发 Linux 设备驱动的经典书籍当属 [Device Drivers, Third Edition](http://lwn.net/Kernel/LDD3) 简称 **LDD3**。该书籍是免费的，可以自由下载并按照其规定的 License 重新分发。

### 2. 模块初始化和退出

Linux 驱动模块的开发遵守 Linux 为模块开发者提供的基本框架和 API。LDD3 的 [hello world](https://github.com/martinezjavier/ldd3/blob/master/misc-modules/hello.c) 模块提供了写一个最简内核模块的例子。
而 Sampleblk 块驱动的模块与之类似，实现了 Linux 内核模块所必需的模块初始化和退出函数，

	module_init(sampleblk_init);
	module_exit(sampleblk_exit);

#### 2.1 sampleblk_init

##### 2.1.1 块设备注册

##### 2.1.2 磁盘创建和初始化

##### 2.1.3 块设备操作函数表

#### 2.2 sampleblk_exit

#### 3. 策略函数实现

##### 3.1 IO Requeust Queue

##### 3.2 IO Request

##### 3.3 BIO 结构

### 4. 试验

#### 4.1 模块引用问题解决

#### 4.2 创建文件系统

### 5. 延伸阅读

* [Using kdb/kgdb debug Linux kernel - 1](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-1/)
* [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/)
* [Debugging kernel and modules via gdb](https://github.com/torvalds/linux/blob/master/Documentation/gdb-kernel-debugging.txt)
* [Linux Crash Utility - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash Utility - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
