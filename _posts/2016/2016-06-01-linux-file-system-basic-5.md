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

与 Day1 和 Day2 的代码相比，Day3 的实现是最简单的。下面就其中的知识点做简单介绍。

### 2.1 模块参数

Day3 这段代码示意了如何声明模块的参数，

	unsigned int sample_parm = 0;
	module_param(sample_parm, int, 0);
	MODULE_PARM_DESC(sample_parm, "An example parm. Default: x Range: y to z");

其中 `module_param` 用来声明模块的变量名，数据类型和许可掩码 (permission masks)。由于本驱动的许可掩码是 0，因此模块参数并未在 `/sys/module/` 路径下创建参数文件。

### 2.2 调试信息

在 Day3 代码里使用了 `printk` 的变体 `pr_info`, `pr_warn` 和 `pr_err`，这些函数都是直接包装 `printk`，让代码更简洁一些。
还有其它类似的函数定义在了 `include/linux/printk.h` 里。

	#define pr_emerg(fmt, ...) \
	     printk(KERN_EMERG pr_fmt(fmt), ##__VA_ARGS__)
	#define pr_alert(fmt, ...) \
	    printk(KERN_ALERT pr_fmt(fmt), ##__VA_ARGS__)
	#define pr_crit(fmt, ...) \
	    printk(KERN_CRIT pr_fmt(fmt), ##__VA_ARGS__)
	#define pr_err(fmt, ...) \
	    printk(KERN_ERR pr_fmt(fmt), ##__VA_ARGS__)
	#define pr_warning(fmt, ...) \
	    printk(KERN_WARNING pr_fmt(fmt), ##__VA_ARGS__)
	#define pr_warn pr_warning
	#define pr_notice(fmt, ...) \
	    printk(KERN_NOTICE pr_fmt(fmt), ##__VA_ARGS__)
	#define pr_info(fmt, ...) \
	     printk(KERN_INFO pr_fmt(fmt), ##__VA_ARGS__)

	/* If you are writing a driver, please use dev_dbg instead */
	#if defined(CONFIG_DYNAMIC_DEBUG)
	/* dynamic_pr_debug() uses pr_fmt() internally so we don't need it here */
	#define pr_debug(fmt, ...) \
	    dynamic_pr_debug(fmt, ##__VA_ARGS__)
	#elif defined(DEBUG)
	#define pr_debug(fmt, ...) \
	    printk(KERN_DEBUG pr_fmt(fmt), ##__VA_ARGS__)
	#else
	#define pr_debug(fmt, ...) \
	    no_printk(KERN_DEBUG pr_fmt(fmt), ##__VA_ARGS__)
	#endif

这里面，`pr_debug` 是个特例。在 `CONFIG_DYNAMIC_DEBUG` 打开的前提下，`pr_debug` 实现了内核的 [Dynamic debug](https://www.kernel.org/doc/ols/2009/ols2009-pages-39-46.pdf) 特性。
这个特性使得 `pr_debug` 打印的消息可以在默认情况下不被使能，但通过控制 `/sys/kernel/debug/dynamic_debug/control` 来实现动态的使能。
详细用法请参考 [Documentation/dynamic-debug-howto.txt](https://github.com/torvalds/linux/blob/master/Documentation/dynamic-debug-howto.txt)。

### 2.3 proc 文件系统

## 4. 实验

	$ sudo insmod /home/yango/ws/lktm/fs/samplefs/day3/samplefs.ko sample_parm=9000

	[96287.090137] init samplefs
	[96287.090143] sample_parm 9000 too large, reset to 10

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
