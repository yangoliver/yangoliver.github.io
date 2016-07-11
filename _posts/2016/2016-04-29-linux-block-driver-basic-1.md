---
layout: post
title: Linux Block Driver - 1
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, crash, kernel, linux, storage]
---

>本文首发于<http://oliveryang.net>，转载时请包含原文或者作者网站链接。

* content
{:toc}

## 1. 背景

Sampleblk 是一个用于学习目的的 Linux 块设备驱动项目。其中 [day1](https://github.com/yangoliver/lktm/tree/master/drivers/block/sampleblk/day1) 的源代码实现了一个最简的块设备驱动，源代码只有 200 多行。
本文主要围绕这些源代码，讨论 Linux 块设备驱动开发的基本知识。

开发 Linux 驱动需要做一系列的开发环境准备工作。Sampleblk 驱动是在 Linux 4.6.0 下开发和调试的。由于在不同 Linux 内核版本的通用 block 层的 API 有很大变化，这个驱动在其它内核版本编译可能会有问题。
开发，编译，调试内核模块需要先准备内核开发环境，编译内核源代码。这些基础的内容互联网上随处可得，本文不再赘述。

此外，开发 Linux 设备驱动的经典书籍当属 [Device Drivers, Third Edition](http://lwn.net/Kernel/LDD3) 简称 **LDD3**。该书籍是免费的，可以自由下载并按照其规定的 License 重新分发。

## 2. 模块初始化和退出

Linux 驱动模块的开发遵守 Linux 为模块开发者提供的基本框架和 API。LDD3 的 [hello world](https://github.com/martinezjavier/ldd3/blob/master/misc-modules/hello.c) 模块提供了写一个最简内核模块的例子。
而 Sampleblk 块驱动的模块与之类似，实现了 Linux 内核模块所必需的模块初始化和退出函数，

	module_init(sampleblk_init);
	module_exit(sampleblk_exit);

与 hello world 模块不同的是，Sampleblk 驱动的初始化和退出函数要实现一个块设备驱动程序所必需的基本功能。本节主要针对这部分内容做详细说明。

### 2.1 sampleblk_init

归纳起来，`sampleblk_init` 函数为完成块设备驱动的初始化，主要做了以下几件事情，

#### 2.1.1 块设备注册

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

#### 2.1.2 驱动状态数据结构的分配和初始化

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

#### 2.1.3 Request Queue 初始化

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

#### 2.1.4 块设备操作函数表初始化

Linux 的块设备操作函数表 `block_device_operations` 定义在 `include/linux/blkdev.h` 文件中。块设备驱动可以通过定义这个操作函数表来实现对标准块设备驱动操作函数的定制。
如果驱动没有实现这个操作表定义的方法，Linux 块设备层的代码也会按照块设备公共层的代码缺省的行为工作。

Sampleblk 驱动虽然声明了自己的 `open`, `release`, `ioctl` 方法，但这些方法对应的驱动函数内都没有做实质工作。因此实际的块设备操作时的行为是由块设备公共层来实现的，

	static const struct block_device_operations sampleblk_fops = {
	    .owner = THIS_MODULE,
	    .open = sampleblk_open,
	    .release = sampleblk_release,
	    .ioctl = sampleblk_ioctl,
	};

#### 2.1.5 磁盘创建和初始化

Linux 内核使用 `struct gendisk` 来抽象和表示一个磁盘。也就是说，块设备驱动要支持正常的块设备操作，必需分配和初始化一个 `struct gendisk`。

首先，使用 `alloc_disk` 分配一个 `struct gendisk`，

    disk = alloc_disk(minor);
    if (!disk) {
        rv = -ENOMEM;
        goto fail_queue;
    }
    sampleblk_dev->disk = disk;

然后，初始化 `struct gendisk` 的重要成员，尤其是块设备操作函数表，Rquest Queue，和容量设置。最终调用 `add_disk` 来让磁盘在系统内可见，触发磁盘热插拔的 uevent。

    disk->major = sampleblk_major;
    disk->first_minor = minor;
    disk->fops = &sampleblk_fops;
    disk->private_data = sampleblk_dev;
    disk->queue = sampleblk_dev->queue;
    sprintf(disk->disk_name, "sampleblk%d", minor);
    set_capacity(disk, sampleblk_nsects);
    add_disk(disk);

### 2.2 sampleblk_exit

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

## 3. 策略函数实现

理解块设备驱动的策略函数实现，必需先对 Linux IO 栈的关键数据结构有所了解。

### 3.1 `struct request_queue`

块设备驱动待处理的 IO 请求队列结构。如果该队列是利用 `blk_init_queue` 分配和初始化的，则该队里内的 IO 请求( `struct request` ）需要经过 IO 调度器的处理(排序或合并)，由 `blk_queue_bio` 触发。

当块设备策略驱动函数被调用时，`request` 是通过其 `queuelist` 成员链接在 `struct request_queue` 的 `queue_head` 链表里的。
一个 IO 申请队列上会有很多个 `request` 结构。

### 3.2 `struct bio`

一个 `bio` 逻辑上代表了上层某个任务对**通用块设备层**发起的 IO 请求。来自不同应用，不同上下文的，不同线程的 IO 请求在块设备驱动层被封装成不同的 `bio` 数据结构。

同一个 `bio` 结构的数据是由块设备上**从起始扇区开始的物理连续扇区**组成的。由于在块设备上连续的物理扇区在内存中无法保证是物理内存连续的，因此才有了**段 (Segment)**的概念。
在 Segment 内部的块设备的扇区是**物理内存连续**的，但 Segment 之间却不能保证物理内存的连续性。Segment 长度不会超过内存页大小，而且总是扇区大小的整数倍。

下图清晰的展现了扇区 (Sector)，块 (Block) 和段 (Segment) 在内存页 (Page) 内部的布局，以及它们之间的关系(注：图截取自 Understand Linux Kernel 第三版，版权归原作者所有)，

![Segment block sector layout in a page](/media/images/2016/page_segment_block_sector.png)

因此，一个 Segment 可以用 [page, offset, len] 来唯一确定。一个 `bio` 结构可以包含多个 Segment。而 `bio` 结构通过指向 Segment 的指针数组来表示了这种一对多关系。

在 `struct bio` 中，成员 `bi_io_vec` 就是前文所述的“指向 Segment 的指针数组” 的基地址，而每个数组的元素就是指向 `struct bio_vec` 的指针。

	struct bio {

		[...snipped..]

		struct bio_vec      *bi_io_vec; /* the actual vec list */

		[...snipped..]
	}


而 `struct bio_vec` 就是描述一个 Segment 的数据结构，

	struct bio_vec {
	    struct page *bv_page;       /* Segment 所在的物理页的 struct page 结构指针 */
	    unsigned int    bv_len;     /* Segment 长度，扇区整数倍 */
	    unsigned int    bv_offset;  /* Segment 在物理页内起始的偏移地址 */
	};

在 `struct bio` 中的另一个成员 `bi_vcnt` 用来描述这个 `bio` 里有多少个 Segment，即指针数组的元素个数。一个 `bio` 最多包含的 Segment/Page 数是由如下内核宏定义决定的，

	#define BIO_MAX_PAGES       256

多个 `bio` 结构可以通过成员 `bi_next` 链接成一个链表。`bio` 链表可以是某个做 IO 的任务 `task_struct` 成员 `bio_list` 所维护的一个链表。也可以是某个 `struct request` 所属的一个链表(下节内容)。

下图展现了 `bio` 结构通过 `bi_next` 链接组成的链表。其中的每个 `bio` 结构和 Segment/Page 存在一对多关系 (注：图截取自 Professional Linux Kernel Architecture，版权归原作者所有)，

![bio list and page vectors](/media/images/2016/bio_page.png)

### 3.3 `struct request`

一个 `request` 逻辑上代表了**块设备驱动层**收到的 IO 请求。该 IO 请求的数据在块设备上是**从起始扇区开始的物理连续扇区**组成的。

在 `struct request` 里可以包含很多个 `struct bio`，主要是通过 `bio` 结构的 `bi_next` 链接成一个链表。这个链表的第一个 `bio` 结构，则由 `struct request` 的 `bio` 成员指向。
而链表的尾部则由 `biotail` 成员指向。

通用块设备层接收到的来自不同线程的 `bio` 后，通常根据情况选择如下两种方案之一，

* 将 `bio` 合并入已有的 `request`

  `blk_queue_bio` 会调用 IO 调度器做 IO 的**合并 (merge)**。多个 `bio` 可能因此被合并到同一个 `request` 结构里，组成一个 `request` 结构内部的 `bio` 结构链表。
  由于每个 `bio` 结构都来自不同的任务，因此 IO 请求合并只能在 `request` 结构层面通过链表插入排序完成，原有的 `bio` 结构内部不会被修改。

* 分配新的 `request`

  如果 `bio` 不能被合并到已有的 `request` 里，通用块设备层就会为这个 `bio` 构造一个新 `request` 然后插入到 IO 调度器内部的队列里。
  待上层任务通过 `blk_finish_plug` 来触发 `blk_run_queue` 动作，块设备驱动的策略函数 `request_fn` 会触发 IO 调度器的排序操作，将 `request` 排序插入块设备驱动的 IO 请求队列。

不论以上哪种情况，通用块设备的代码将会调用块驱动程序注册在 `request_queue` 的 `request_fn` 回调，这个回调里最终会将合并或者排序后的 `request` 交由驱动的底层函数来做 IO 操作。

### 3.4 策略函数 `request_fn`

如前所述，当块设备驱动使用 `blk_run_queue` 来分配和初始化 `request_queue` 时，这个函数也需要驱动指定自定义的策略函数 `request_fn` 和所需的自旋锁 `queue_lock`。
驱动实现自己的 `request_fn` 时，需要了解如下特点，

* 当通用块层代码调用 `request_fn` 时，内核已经拿了这个 `request_queue` 的 `queue_lock`。
  因此，此时的上下文是 atomic 上下文。在驱动的策略函数退出 `queue_lock` 之前，需要遵守内核在 atomic 上下文的约束条件。

* 进入驱动策略函数时，通用块设备层代码可能会同时访问 `request_queue`。为了减少在 `request_queue` 的 `queue_lock` 上的锁竞争, 块驱动策略函数应该尽早退出 `queue_lock`，然后在策略函数返回前重新拿到锁。

* 策略函数是异步执行的，不处在用户态进程所对应的内核上下文。因此实现时不能假设策略函数运行在用户进程的内核上下文中。

Sampleblk 的策略函数是 sampleblk_request，通过 `blk_init_queue` 注册到了 `request_queue` 的 `request_fn` 成员上。

	static void sampleblk_request(struct request_queue *q)
	{
		struct request *rq = NULL;
		int rv = 0;
		uint64_t pos = 0;
		ssize_t size = 0;
		struct bio_vec bvec;
		struct req_iterator iter;
		void *kaddr = NULL;

		while ((rq = blk_fetch_request(q)) != NULL) {
			spin_unlock_irq(q->queue_lock);

			if (rq->cmd_type != REQ_TYPE_FS) {
				rv = -EIO;
				goto skip;
			}

			BUG_ON(sampleblk_dev != rq->rq_disk->private_data);

			pos = blk_rq_pos(rq) * sampleblk_sect_size;
			size = blk_rq_bytes(rq);
			if ((pos + size > sampleblk_dev->size)) {
				pr_crit("sampleblk: Beyond-end write (%llu %zx)\n", pos, size);
				rv = -EIO;
				goto skip;
			}

			rq_for_each_segment(bvec, rq, iter) {
				kaddr = kmap(bvec.bv_page);

				rv = sampleblk_handle_io(sampleblk_dev,
					pos, bvec.bv_len, kaddr + bvec.bv_offset, rq_data_dir(rq));
				if (rv < 0)
					goto skip;

				pos += bvec.bv_len;
				kunmap(bvec.bv_page);
			}
	skip:

			blk_end_request_all(rq, rv);

			spin_lock_irq(q->queue_lock);
		}
	}

策略函数 `sampleblk_request` 的实现逻辑如下，

1. 使用 `blk_fetch_request` 循环获取队列中每一个待处理 `request`。
   内核函数 `blk_fetch_request` 可以返回 `struct request_queue` 的 `queue_head` 队列的第一个 `request` 的指针。然后再调用 `blk_dequeue_request` 从队列里摘除这个 `request`。
2. 每拿到一个 `request`，立即退出锁 `queue_lock`，但处理完每个 `request`，需要再次获得 `queue_lock`。
3. `REQ_TYPE_FS` 用来检查是否是一个来自文件系统的 `request`。本驱动不支持非文件系统 `request`。
4. `blk_rq_pos` 可以返回 `request` 的起始扇区号，而 `blk_rq_bytes` 返回整个 `request` 的字节数，应该是扇区的整数倍。
5. `rq_for_each_segment` 这个宏定义用来**循环迭代**遍历一个 `request` 里的每一个 Segment: 即 `struct bio_vec`。
   注意，每个 Segment 即 `bio_vec` 都是以 `blk_rq_pos` 为起始扇区，物理扇区连续的的。Segment 之间只是物理内存不保证连续而已。
6. 每一个 `struct bio_vec` 都可以利用 kmap 来获得这个 Segment 所在页的虚拟地址。利用 `bv_offset` 和 `bv_len` 可以进一步知道这个 segment 的确切页内偏移和具体长度。
7. `rq_data_dir` 可以获知这个 `request` 的请求是 read 还是 write。
8. 处理完毕该 `request` 之后，必需调用 `blk_end_request_all` 让块通用层代码做后续处理。


驱动函数 `sampleblk_handle_io` 把一个 `request`的每个 segment 都做一次驱动层面的 IO 操作。
调用该驱动函数前，**起始扇区地址 `pos`**，**长度 `bv_len`**, **起始扇区虚拟内存地址 `kaddr + bvec.bv_offset`**，和 **read/write** 都做为参数准备好。
由于 Sampleblk 驱动只是一个 ramdisk 驱动，因此，每个 segment 的 IO 操作都是 `memcpy` 来实现的，

	/*
	 * Do an I/O operation for each segment
	 */
	static int sampleblk_handle_io(struct sampleblk_dev *sampleblk_dev,
			uint64_t pos, ssize_t size, void *buffer, int write)
	{
		if (write)
			memcpy(sampleblk_dev->data + pos, buffer, size);
		else
			memcpy(buffer, sampleblk_dev->data + pos, size);

		return 0;
	}

## 4. 试验

### 4.1 编译和加载

* 首先，需要下载内核源代码，编译和安装内核，用新内核启动。

  由于本驱动是在 Linux 4.6.0 上开发和调试的，而且块设备驱动内核函数不同内核版本变动很大，最好去下载 Linux mainline 源代码，然后 git checkout 到版本 4.6.0 上编译内核。
  编译和安装内核的具体步骤网上有很多介绍，这里请读者自行解决。

* 编译好内核后，在内核目录，编译驱动模块。

	  $ make M=/ws/lktm/drivers/block/sampleblk/day1

* 驱动编译成功，加载内核模块

	  $ sudo insmod /ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko

* 驱动加载成功后，使用 crash 工具，可以查看 `struct smapleblk_dev` 的内容，

	  crash7> mod -s sampleblk /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko
	       MODULE       NAME                   SIZE  OBJECT FILE
	  ffffffffa03bb580  sampleblk              2681  /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko

	  crash7> p *sampleblk_dev
	  $4 = {
	    minor = 1,
	    lock = {
	      {
	        rlock = {
	          raw_lock = {
	            val = {
	              counter = 0
	            }
	          }
	        }
	      }
	    },
	    queue = 0xffff880034ef9200,
	    disk = 0xffff880000887000,
	    size = 524288,
	    data = 0xffffc90001a5c000
	  }

注：关于 Linux Crash 的使用，请参考延伸阅读。

### 4.2 模块引用问题解决

问题：把驱动的 `sampleblk_request` 函数实现全部删除，重新编译和加载内核模块。然后用 rmmod 卸载模块，卸载会失败, 内核报告模块正在被使用。

使用 `strace` 可以观察到 `/sys/module/sampleblk/refcnt` 非零，即模块正在被使用。

	$ strace rmmod sampleblk
	execve("/usr/sbin/rmmod", ["rmmod", "sampleblk"], [/* 26 vars */]) = 0

	................[snipped]..........................

	openat(AT_FDCWD, "/sys/module/sampleblk/holders", O_RDONLY|O_NONBLOCK|O_DIRECTORY|O_CLOEXEC) = 3
	getdents(3, /* 2 entries */, 32768)     = 48
	getdents(3, /* 0 entries */, 32768)     = 0
	close(3)                                = 0
	open("/sys/module/sampleblk/refcnt", O_RDONLY|O_CLOEXEC) = 3	/* 显示引用数为 3 */
	read(3, "1\n", 31)                      = 2
	read(3, "", 29)                         = 0
	close(3)                                = 0
	write(2, "rmmod: ERROR: Module sampleblk i"..., 41rmmod: ERROR: Module sampleblk is in use
	) = 41
	exit_group(1)                           = ?
	+++ exited with 1 +++

如果用 `lsmod` 命令查看，可以看到模块的引用计数确实是 3，但没有显示引用者的名字。一般情况下，只有内核模块间的相互引用才有引用模块的名字，所以没有引用者的名字，那么引用者来自用户空间的进程。

那么，究竟是谁在使用 sampleblk 这个刚刚加载的驱动呢？利用 `module:module_get` tracepoint，就可以得到答案了。
重新启动内核，在加载模块前，运行 [`tpoint` 命令](https://github.com/brendangregg/perf-tools/blob/master/system/tpoint)。然后，再运行 `insmod` 来加载模块。

	$ sudo ./tpoint module:module_get
	Tracing module:module_get. Ctrl-C to end.

	   systemd-udevd-2986  [000] ....   196.382796: module_get: sampleblk call_site=get_disk refcnt=2
	   systemd-udevd-2986  [000] ....   196.383071: module_get: sampleblk call_site=get_disk refcnt=3

可以看到，原来是 systemd 的 udevd 进程在使用 sampleblk 设备。如果熟悉 udevd 的人可能就会立即恍然大悟，因为 udevd 负责侦听系统中所有设备的热插拔事件，并负责根据预定义规则来对新设备执行一系列操作。
而 sampleblk 驱动在调用 `add_disk` 时，`kobject` 层的代码会向用户态的 udevd 发送热插拔的 `uevent`，因此 udevd 会打开块设备，做相关的操作。
利用 crash 命令，可以很容易找到是哪个进程在打开 sampleblk 设备，

	crash> foreach files -R /dev/sampleblk
	PID: 4084   TASK: ffff88000684d700  CPU: 0   COMMAND: "systemd-udevd"
	ROOT: /    CWD: /
	 FD       FILE            DENTRY           INODE       TYPE PATH
	  8 ffff88000691ad00 ffff88001ffc0600 ffff8800391ada08 BLK  /dev/sampleblk1
	  9 ffff880006918e00 ffff88001ffc0600 ffff8800391ada08 BLK  /dev/sampleblk1

由于 `sampleblk_request` 函数实现被删除，则 `udevd` 发送的 IO 操作无法被 sampleblk 设备驱动完成，因此 udevd 陷入到长期的阻塞等待中，直到超时返回错误，释放设备。
上述分析可以从系统的消息日志中被证实，

	messages:Apr 23 03:11:51 localhost systemd-udevd: worker [2466] /devices/virtual/block/sampleblk1 is taking a long time
	messages:Apr 23 03:12:02 localhost systemd-udevd: worker [2466] /devices/virtual/block/sampleblk1 timeout; kill it
	messages:Apr 23 03:12:02 localhost systemd-udevd: seq 4313 '/devices/virtual/block/sampleblk1' killed

注：`tpoint` 是一个基于 ftrace 的开源的 bash 脚本工具，可以直接下载运行使用。它是 [Brendan Gregg](http://www.brendangregg.com/index.html) 在 github 上的开源项目，前文已经给出了项目的链接。

重新把删除的 `sampleblk_request` 函数源码加回去，则这个问题就不会存在。因为 udevd 可以很快结束对 sampleblk 设备的访问。

### 4.3 创建文件系统

虽然 Sampleblk 块驱动只有 200 行源码，但已经可以当作 ramdisk 来使用，在其上可以创建文件系统，

	$ sudo mkfs.ext4 /dev/sampleblk1

文件系统创建成功后，`mount` 文件系统，并创建一个空文件 a。可以看到，都可以正常运行。

	$sudo mount /dev/sampleblk1 /mnt
	$touch a

至此，sampleblk 做为 ramdisk 的最基本功能已经实验完毕。

## 5. 延伸阅读

* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Device Drivers, Third Edition](http://lwn.net/Kernel/LDD3)
