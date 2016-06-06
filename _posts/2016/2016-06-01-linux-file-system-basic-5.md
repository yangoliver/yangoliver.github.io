---
layout: post
title: Linux File System - 5
description: Linux file system(文件系统)模块的实现和基本数据结构。关键字：文件系统，内核，samplefs，VFS，存储。
categories: [Chinese, Software]
tags:
- [file system, driver, crash, kernel, linux, storage]
---

>本文处于未完成状态，内容可能随时更改。

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

* content
{:toc}

## 1. 背景

本文继续 Samplefs 的源码介绍。[Day3 的源码](https://github.com/yangoliver/lktm/tree/master/fs/samplefs/day3)主要是在状态和调试方面的改进。

## 2. 代码

### 2.1 模块参数

下面这段代码示意了如何声明模块的参数，

	unsigned int sample_parm = 0;
	module_param(sample_parm, int, 0);
	MODULE_PARM_DESC(sample_parm, "An example parm. Default: x Range: y to z");

其中 `module_param` 用来声明模块的变量名，数据类型和许可掩码 (permission masks)。

### 2.2 调试信息

### 2.3 proc 文件系统

## 4. 实验


	$ sudo insmod /home/yango/ws/lktm/fs/samplefs/day3/samplefs.ko sample_parm=9000

	$ modinfo /home/yango/ws/lktm/fs/samplefs/day3/samplefs.ko
	filename:       /home/yango/ws/lktm/fs/samplefs/day3/samplefs.ko
	license:        GPL
	srcversion:     A7EB3525B6F9C78912A2FDE
	depends:
	vermagic:       4.6.0-rc3+ SMP mod_unload modversions
	parm:           sample_parm:An example parm. Default: x Range: y to z (int)

## 5. 延伸阅读

* [Linux File System - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1)
* [Linux File System - 2](http://oliveryang.net/2016/01/linux-file-system-basic-2)
* [Linux File System - 3](http://oliveryang.net/2016/02/linux-file-system-basic-3)
* [Linux File System - 4](http://oliveryang.net/2016/05/linux-file-system-basic-4)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background)
* [Linux Crash - coding notes](http://oliveryang.net/2015/07/linux-crash-coding-notes/)
* [在Fedora 20环境下安装系统内核源代码](http://www.cnblogs.com/kuliuheng/p/3976780.html)
* [Linux Crash White Paper (了解 crash 命令)](http://people.redhat.com/anderson/crash_whitepaper)
