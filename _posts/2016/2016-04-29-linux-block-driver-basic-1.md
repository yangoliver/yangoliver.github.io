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

Linux 内核提供了多种分配和初始化 Request Queue 的方法，

* `blk_mq_init_queue` 主要用于使用多队列技术的块设备驱动
* `blk_alloc_queue` 和 `blk_queue_make_request` 主要用于绕开内核支持的 IO 调度器的合并和排序，使用自定义的实现。
* `blk_init_queue` 则使用内核支持的 IO 调度器，驱动只专注于策略函数的实现。

Sampleblk 驱动属于第三种情况。这里再次强调一下：**如果块设备驱动需要使用标准的 IO 调度器对 IO 请求进行合并或者排序时，必需使用 `blk_init_queue` 来分配和初始化 Request Queue**.

##### 2.1.4 块设备操作函数表初始化

Linux 的块设备操作函数表 `block_device_operations` 定义在 `include/linux/blkdev.h` 文件中。块设备驱动可以通过定义这个操作函数表来实现对标准块设备驱动操作函数的定制。
如果驱动没有实现这个操作表定义的方法，Linux 块设备层的代码也会按照块设备公共层的代码缺省的行为工作。

Sampleblk 驱动虽然声明了自己的 `open`, `release`, `ioctl` 方法，但这些方法对应的驱动函数内都没有做实质工作。因此实际的块设备操作时的行为是由块设备公共层来实现的，

	static const struct block_device_operations sampleblk_fops = {
	    .owner = THIS_MODULE,
	    .open = sampleblk_open,
	    .release = sampleblk_release,
	    .ioctl = sampleblk_ioctl,
	};

##### 2.1.5 磁盘创建和初始化

Linux 内核使用 `struct gendisk` 来抽象和表示一个磁盘。也就是说，块设备驱动要支持正常的块设备操作，必需分配和初始化一个 `struct gendisk`。

首先，使用 `alloc_disk` 分配一个 `struct gendisk`，

    disk = alloc_disk(minor);
    if (!disk) {
        rv = -ENOMEM;
        goto fail_queue;
    }
    sampleblk_dev->disk = disk;
    pr_info("gendisk address %p\n", disk);

然后，初始化 `struct gendisk` 的重要成员，尤其是块设备操作函数表，Rquest Queue，和容量设置。最终调用 `add_disk` 来让磁盘在系统内可见，触发磁盘热插拔的 uevent。

    disk->major = sampleblk_major;
    disk->first_minor = minor;
    disk->fops = &sampleblk_fops;
    disk->private_data = sampleblk_dev;
    disk->queue = sampleblk_dev->queue;
    sprintf(disk->disk_name, "sampleblk%d", minor);
    set_capacity(disk, sampleblk_nsects);
    add_disk(disk);

#### 2.2 sampleblk_exit

这是个 `sampleblk_init` 的逆过程，

* 删除磁盘

  `del_gendisk` 是 `add_disk` 的逆过程，让磁盘在系统中不再可见，触发热插拔 uevent。

       del_gendisk(sampleblk_dev->disk);

* 停止并释放块设备 IO 请求队列

  `blk_cleanup_queue` 是 `blk_init_queue` 的逆过程，但其在释放 `struct request_queue` 之前，要把待处理的 IO 请求都处理掉。

       blk_cleanup_queue(sampleblk_dev->queue);

  当 `blk_cleanup_queue` 把所有 IO 请求全部处理完时，会标记这个队列马上要被释放，这样可以阻止 `blk_run_queue` 继续调用块驱动的策略函数，继续执行 IO 请求。
  Linux 3.8 之前，内核在 `blk_run_queue` 和 `blk_cleanup_queue` 同时执行时有[严重 bug](https://github.com/torvalds/linux/commit/c246e80d86736312933646896c4157daf511dadc)。
  最近在一个有磁盘 IO 时的 Surprise Remove 的压力测试中发现了这个 bug （老实说，有些惊讶，这个 bug 存在这么久一直没人发现)。

* 释放磁盘

  `put_disk` 是 `alloc_disk` 的逆过程。这里 `gendisk` 对应的 `kobject` 引用计数变为零，彻底释放掉 `gendisk`。

       put_disk(sampleblk_dev->disk);

* 释放数据区

  `vfree` 是 `vmalloc` 的逆过程。

       vfree(sampleblk_dev->data);

* 释放驱动全局数据结构。

  `free` 是 `kzalloc` 的逆过程。

       kfree(sampleblk_dev);

* 注销块设备。

  `unregister_blkdev` 是 `register_blkdev` 的逆过程。

       unregister_blkdev(sampleblk_major, "sampleblk");

#### 3. 策略函数实现

理解块设备驱动的策略函数实现，必需先对 Linux IO 栈的关键数据结构有所了解。

##### 3.1 `struct request_queue`

块设备驱动待处理的 IO 请求队列结构。如果该队列是利用 `blk_init_queue` 分配和初始化的，则该队里内的 IO 请求已经经过 IO 调度器的处理(排序或合并)。

##### 3.2 `struct request`

块设备驱动要处理的 IO 申请。当块设备策略驱动函数被调用时，IO 申请是通过其 `queuelist` 成员链接在 `struct request_queue` 的 `queue_head` 链表里的。
一个 IO 申请队列上会有很多个 IO 申请。

内核函数 `blk_fetch_request` 可以返回 `struct request_queue` 的 `queue_head` 队列的第一个 IO 申请的指针。请注意，这个函数并不把 IO 申请从队列头部摘除出来。

##### 3.3 `struct bio`


##### 3.4 策略函数 `request_fn`

### 4. 试验

#### 4.1 模块引用问题解决

#### 4.2 创建文件系统

### 5. 延伸阅读

* [Using kdb/kgdb debug Linux kernel - 1](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-1/)
* [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/)
* [Debugging kernel and modules via gdb](https://github.com/torvalds/linux/blob/master/Documentation/gdb-kernel-debugging.txt)
* [Linux Crash Utility - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash Utility - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
