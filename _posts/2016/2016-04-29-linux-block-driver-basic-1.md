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

与 hello world 模块不同的是，Sampleblk 驱动的初始化和退出函数要实现一个块设备驱动程序所必需的基本功能。本节主要针对这部分内容做详细说明。

#### 2.1 sampleblk_init

归纳起来，`sampleblk_init` 函数为完成块设备驱动的初始化，主要做了以下几件事情，

##### 2.1.1 块设备注册

调用 `register_blkdev` 完成 major number 的分配和注册，函数原型如下，

	int register_blkdev(unsigned int major, const char *name);

Linux 内核为块设备驱动维护了一个全局哈希表 `major_names`这个哈希表的 bucket 是 ［0..255] 的整数索引的指向 `blk_major_name` 的结构指针数组。

	static struct blk_major_name {
	    struct blk_major_name *next;
	    int major;
	    char name[16];
	} *major_names[BLKDEV_MAJOR_HASH_SIZE];

而 `register_blkdev` 的 `major` 参数不为 0 时，其实现就尝试在这个哈希表中寻找指定的 `major` 对应的 bucket 里的空闲指针，分配一个新的 `blk_major_name`，按照指定参数初始化 `major` 和 `name`。
假如指定的 `major` 已经被别人占用(指针非空)，则表示 `major` 号冲突，反回错误。

当 `major` 参数为 0 时，则由内核从 [1..255] 的整数范围内分配一个未使用的反回给调用者。因此，虽然 Linux 内核的**主设备号 (Major Number)** 是 12 位的，不指定 `major` 时，仍旧从 [1..255] 范围内分配。

Sampleblk 驱动通过指定 `major` 为 0，让内核为其分配和注册一个未使用的主设备号，其代码如下，

    sampleblk_major = register_blkdev(0, "sampleblk");
    if (sampleblk_major < 0)
        return sampleblk_major;

##### 2.1.2 驱动状态数据结构的分配和初始化

通常，所有 Linux 内核驱动都会声明一个数据结构来存储驱动需要频繁访问的状态信息。这里，我们为 Sampleblk 驱动也声明了一个，

	struct sampleblk_dev {
	    int minor;
	    spinlock_t lock;
	    struct request_queue *queue;
	    struct gendisk *disk;
	    ssize_t size;
	    void *data;
	};

为了简化实现和方便调试，Sampleblk 驱动暂时只支持一个 minor 设备号，并且可以用以下全局变量访问，

	struct sampleblk_dev *sampleblk_dev = NULL;

下面的代码分配了 `sampleblk_dev` 结构，并且给结构的成员做了初始化，

    sampleblk_dev = kzalloc(sizeof(struct sampleblk_dev), GFP_KERNEL);
    if (!sampleblk_dev) {
        rv = -ENOMEM;
        goto fail;
    }

    sampleblk_dev->size = sampleblk_sect_size * sampleblk_nsects;
    sampleblk_dev->data = vmalloc(sampleblk_dev->size);
    if (!sampleblk_dev->data) {
        rv = -ENOMEM;
        goto fail_dev;
	}
	sampleblk_dev->minor = minor;

##### 2.1.3 Request Queue 初始化

使用 `blk_init_queue` 初始化 Request Queue 需要先声明一个所谓的策略 (Strategy) 回调和保护该 Request Queue 的自旋锁。
然后将该策略回调的函数指针和自旋锁指针做为参数传递给该函数。

在 Sampleblk 驱动里，就是 `sampleblk_request` 函数和 `sampleblk_dev->lock`，

    spin_lock_init(&sampleblk_dev->lock);
    sampleblk_dev->queue = blk_init_queue(sampleblk_request,
        &sampleblk_dev->lock);
    if (!sampleblk_dev->queue) {
        rv = -ENOMEM;
        goto fail_data;
    }

策略函数 `sampleblk_request` 用于执行块设备的 read 和 write IO 操作，其主要的入口参数就是 Request Queue 结构：`struct request_queue`。
关于策略函数的具体实现我们稍后介绍。

当执行 `blk_init_queue` 时，其内部实现会做如下的处理，

1. 从内存中分配一个 `struct request_queue` 结构。
2. 初始化 `struct request_queue` 结构。对调用者来说，其中以下部分的初始化格外重要，
   * `blk_init_queue` 指定的策略函数指针会赋值给 `struct request_queue` 的 `request_fn` 成员。
   * `blk_init_queue` 指定的自旋锁指针会赋值给 `struct request_queue` 的 `queue_lock` 成员。
   * 与这个`request_queue` 关联的 IO 调度器的初始化。

Linux 内核提供了不同的 blk 层的 API 分配和初始化 Request Queue。
可是，**如果块设备驱动需要使用标准的 IO 调度器对 IO 请求进行合并或者排序时，必需使用 `blk_init_queue` 来分配和初始化 Request Queue**.

##### 2.1.4 磁盘创建和初始化


##### 2.1.5 块设备操作函数表初始化


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
