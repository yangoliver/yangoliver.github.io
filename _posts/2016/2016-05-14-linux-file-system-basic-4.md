---
layout: post
title: Linux File System - 4
description: Linux file system(文件系统)模块的实现和基本数据结构。关键字：Ext4，文件系统，内核，samplefs，VFS，存储。
categories: [Chinese, Software]
tags:
- [file system, driver, crash, kernel, linux, storage]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

>本文仍处于未完成状态，内容随时可能修改。

* content
{:toc}

## 1. 背景

本文将在 Sampleblk 块设备上创建 Ext4 文件系统，以 Ext4 文件系统为例，用 Crash 来查看 Ext4 文件系统的磁盘格式。

在 [Linux File System - 3](http://oliveryang.net/2016/02/linux-file-system-basic-3) 中，Samplefs 只有文件系统内存中的数据结构，而并未规定文件系统磁盘数据格式 (File System Disk Layout)。
而 [Linux Block Driver - 1](http://oliveryng.net/2016/04/linux-block-driver-basic-1) 则实现了一个最简的块驱动 Sampleblk。 
Sampleblk [day1 的源码](https://github.com/yangoliver/lktm/tree/master/drivers/block/sampleblk/day1)只有 200 多行，但已经可以在它上面创建各种文件系统。
由于 Sampleblk 是个 ramdisk，磁盘数据实际上都写在了驱动分配的内核内存里，因此可以很方便的使用 Linux Crash 工具来研究任意一种文件系统的磁盘格式。

## 2. 准备

### 2.1 Ram Disk 驱动

需要按照如下步骤去准备 Sampleblk 驱动，

* Linux 4.6.0 编译，安装，引导
* Sampleblk 驱动编译和加载
* 在 `/dev/sampleblk1` 上创建 Ext4 文件系统。
* mount 文件系统到 /mnt 上

以上详细过程可以参考 [Linux Block Driver - 1](http://oliveryng.net/2016/04/linux-block-driver-basic-1)。

### 2.2 调试工具

需要做的准备工作如下，

* 升级 Crash 到支持 Linux 4.6.0 内核的版本

  详细过程请参考 [Linux Crash - coding notes](http://oliveryang.net/2015/07/linux-crash-coding-notes/) 这篇文章。

* 确认 debugfs 工具是否安装

  debugfs 是 ext2, ext3, ext4 文件系统提供的文件系统调试工具，通过它我们可以不通过 mount 文件系统而直接访问文件系统的内容，它是 e2fsprogs 软件包的一部分，如果找不到请安装。
  debugfs 的详细使用说明可以通过 [debugfs man page](http://linux.die.net/man/8/debugfs) 得到。

## 3. Ext4 磁盘格式

如 [Linux File System - 3](http://oliveryang.net/2016/02/linux-file-system-basic-3) 中所述。很多磁盘文件系统的重要数据结构都存在三个层面上的实现，

1. VFS 内存层面上的实现。
2. 具体文件系统内存层面上的实现。
3. 具体文件系统磁盘上的实现。

上述 1 和 2 共同组成了文件系统的内存布局 (memory layout)，而 3 则是文件系统磁盘布局 (disk layout) 的主要部分，即本文主要关注的部分。

本小节将对 Ext4 的磁盘格式做简单介绍。Ext2/Ext3 文件系统的磁盘格式与之相似，但 Ext4 在原有版本的基础上做了必要的扩展。

如下图所示，一个 Ext4 文件系统的磁盘格式是由一个引导块和很多个 block group 组成的,

![ext4 block groups](/media/images/2016/ext4_disk_layout_1.png)

其中每个 block group 又包含如下格式，

![ext4 layout in one group](/media/images/2016/ext4_disk_layout_2.png)

上图列出的 block group 和 block group 内部每个部分的具体含义将在本文后续实验章节给出。

### 3.1 Block Group

### 3.2 Super Block

### 3.3 Group Descriptor

### 3.4 Data Block Bitmap

### 3.5 Inode Bitmap

### 3.6 Inode Table

### 3.7 Data Blocks

## 4. 实验

### 4.1 查看 Block Group

在格式化 Ext4 文件系统时，`mkfs.ext4` 命令已经报告了在块设备 `/dev/sampleblk1` 上创建了 1 个 block group，并且给出这个 block group 里的具体 block，fragment 和 inode 的个数,

	$ sudo mkfs.ext4 /dev/sampleblk1
	...[snipped]...

	1 block group
	8192 blocks per group, 8192 fragments per group
	64 inodes per group

	...[snipped]...

同样的，也可以使用 `debugfs` 的 `show_super_stats` 命令得到相应的信息，

	$ sudo debugfs /dev/sampleblk1 -R show_super_stats | grep -i block
	debugfs 1.42.9 (28-Dec-2013)
	Block count:              512
	Reserved block count:     25
	Free blocks:              482
	First block:              1
	Block size:               1024 /* block 的长度 */
	Reserved GDT blocks:      3
	Blocks per group:         8192
	Inode blocks per group:   8
	Flex block group size:    16
	Reserved blocks uid:      0 (user root)
	Reserved blocks gid:      0 (group root)
	 Group  0: block bitmap at 6, inode bitmap at 22, inode table at 38
	           482 free blocks, 53 free inodes, 2 used directories, 53 unused inodes

从 `debugfs` 的命令输出，我们也可以清楚的知道 block group 0 内部的情况。它的 block bitmap，inode bitmap，inode table 的具体位置。

### 4.2 磁盘起始地址和长度

因为 sampleblk 是 ramdisk，因此在此块设备上创建文件系统时，所有的数据都被写在了内存里。所以，可以利用 crash 来查看 Ext4 文件系统在 sampleblk 上的磁盘布局。

首先，需要加载 sampleblk.ko 模块的符号，

	crash7> mod -s sampleblk /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko
	     MODULE       NAME                   SIZE  OBJECT FILE
	ffffffffa03bb580  sampleblk              2681  /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko

然后，通过驱动的全局数据结构 `struct sampleblk_dev` 即可找回磁盘在内存中的起始地址和长度，

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
	  size = 524288,            /* 磁盘在内存中的长度 */
	  data = 0xffffc90001a5c000 /* 此地址为磁盘在内存中的起始地址 */
	}
	crash7> p 524288/8
	$5 = 65536                  /* 换算成字节数 */

### 4.3 查看 Super Block

根据 Ext4 磁盘布局，由于 sampleblk 上只存在一个 block group：group 0，因此，super block 存在于 group 0 上的第一个块。

首先，block group 0 距离磁盘起始位置的偏移是 boot block，而一个 block 的大小我们从前面的例子里可以得知是 1024 字节。因此，可以得到磁盘上 super block 的起始地址，

    crash7> p /x 0xffffc90001a5c000+1024
	$18 = 0xffffc90001a5c400

然后，根据前面得到的 super block 起始地址，直接映射磁盘上的 super block 到 `struct ext4_super_block` 数据结构中，

	crash7> ext4_super_block ffffc90001a5c400
	struct ext4_super_block {
	  s_inodes_count = 64,
	  s_blocks_count_lo = 512,
	  s_r_blocks_count_lo = 25,
	  s_free_blocks_count_lo = 482,
	  s_free_inodes_count = 53,
	  s_first_data_block = 1,
	  s_log_block_size = 0,
	  s_log_cluster_size = 0,
	  s_blocks_per_group = 8192,
	  s_clusters_per_group = 8192,
	  s_inodes_per_group = 64,
	  s_mtime = 1461845760,
	  s_wtime = 1461845760,
	  s_mnt_count = 1,
	  s_max_mnt_count = 65535,
	  s_magic = 61267,
	  s_state = 0,
	  s_errors = 1,
	  s_minor_rev_level = 0,
	  s_lastcheck = 1461845616,
	  s_checkinterval = 0,
	  s_creator_os = 0,
	  s_rev_level = 1,
	  s_def_resuid = 0,
	  s_def_resgid = 0,
	  s_first_ino = 11,
	  s_inode_size = 128,
	  s_block_group_nr = 0,
	  s_feature_compat = 56,
	  s_feature_incompat = 706,
	  s_feature_ro_compat = 121,
	  s_uuid = "D⽢\bn@\341\237\024\002$-92!",
	  s_volume_name = "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000",
	  s_last_mounted = "/mnt\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000",
	  s_algorithm_usage_bitmap = 0,
	  s_prealloc_blocks = 0 '\000',
	  s_prealloc_dir_blocks = 0 '\000',
	  s_reserved_gdt_blocks = 3,

	  ...[snipped]...
	}

而且，可以查看 `ext4_super_block` 的大小，

	crash7> ext4_super_block | grep SIZE
	SIZE: 1024

最后，用 `debugfs` 来检查 crash 查看的 super block 是否不是和 `debugfs` 一样准确，

	$ sudo debugfs /dev/sampleblk1 -R show_super_stats
	debugfs:  show_super_stats
	Filesystem volume name:   <none>
	Last mounted on:          /mnt
	Filesystem UUID:          44e2bda2-086e-40e1-9f14-02242d393221
	Filesystem magic number:  0xEF53
	Filesystem revision #:    1 (dynamic)
	Filesystem features:      ext_attr resize_inode dir_index filetype extent 64bit flex_bg sparse_super huge_file uninit_bg dir_nlink extra_isize
	Filesystem flags:         signed_directory_hash
	Default mount options:    user_xattr acl
	Filesystem state:         not clean
	Errors behavior:          Continue
	Filesystem OS type:       Linux
	Inode count:              64
	Block count:              512
	Reserved block count:     25
	Free blocks:              482
	Free inodes:              53
	First block:              1
	Block size:               1024
	Fragment size:            1024
	Group descriptor size:    64
	Reserved GDT blocks:      3
	Blocks per group:         8192
	Fragments per group:      8192
	Inodes per group:         64
	Inode blocks per group:   8
	Flex block group size:    16
	Filesystem created:       Thu Apr 28 05:13:36 2016
	Last mount time:          Thu Apr 28 05:16:00 2016
	Last write time:          Thu Apr 28 05:16:00 2016
	Mount count:              1
	Maximum mount count:      -1
	Last checked:             Thu Apr 28 05:13:36 2016
	Check interval:           0 (<none>)
	Lifetime writes:          85 kB
	Reserved blocks uid:      0 (user root)
	Reserved blocks gid:      0 (group root)
	First inode:              11
	Inode size:           128
	Default directory hash:   half_md4
	Directory Hash Seed:      35ed5f7d-ee3f-4e05-98fd-14ee24e954f8
	Directories:              2
	 Group  0: block bitmap at 6, inode bitmap at 22, inode table at 38
	           481 free blocks, 52 free inodes, 2 used directories, 52 unused inodes
	           [Checksum 0x8791]


## 5. 延伸阅读

* [Linux Block Driver - 1](http://oliveryng.net/2016/04/linux-block-driver-basic-1)
* [Linux File System - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1)
* [Linux File System - 2](http://oliveryang.net/2016/01/linux-file-system-basic-2)
* [Linux File System - 3](http://oliveryang.net/2016/02/linux-file-system-basic-3)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background)
* [Linux Crash - coding notes](http://oliveryang.net/2015/07/linux-crash-coding-notes/)
* [Ext4 Disk Layout](https://ext4.wiki.kernel.org/index.php/Ext4_Disk_Layout)
* [在Fedora 20环境下安装系统内核源代码](http://www.cnblogs.com/kuliuheng/p/3976780.html)
* [Linux Crash White Paper (了解 crash 命令)](http://people.redhat.com/anderson/crash_whitepaper)
