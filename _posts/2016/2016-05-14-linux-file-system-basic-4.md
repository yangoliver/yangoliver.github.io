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

首先，需要加载 sampleblk.ko 和 ext4 模块的符号，

	crash> mod -s sampleblk /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko
	     MODULE       NAME                   SIZE  OBJECT FILE
	ffffffffa03dd580  sampleblk              2681  /home/yango/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko

	crash> mod -s ext4 /lib/modules/4.6.0-rc3+/kernel/fs/ext4/ext4.ko
	     MODULE       NAME                   SIZE  OBJECT FILE
	ffffffffa063cc40  ext4                 574717  /lib/modules/4.6.0-rc3+/kernel/fs/ext4/ext4.ko

然后，通过驱动的全局数据结构 `struct sampleblk_dev` 即可找回磁盘在内存中的起始地址和长度，

	crash7> p *sampleblk_dev
	$1 = {
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
	  queue = 0xffff880034e38000,
	  disk = 0xffff880034268000,
	  size = 524288, /* 磁盘在内存中的长度 */
	  data = 0xffffc900017bc000 /*此地址为磁盘在内存中的起始地址 */
	}

	crash7> p 524288/8
	$5 = 65536                  /* 换算成字节数 */

### 4.3 查看 Super Block

根据 Ext4 磁盘布局，由于 sampleblk 上只存在一个 block group：group 0，因此，super block 存在于 group 0 上的第一个块。

首先，block group 0 距离磁盘起始位置的偏移是 boot block，而一个 block 的大小我们从前面的例子里可以得知是 1024 字节。因此，可以得到磁盘上 super block 的起始地址，

	crash> p /x 0xffffc900017bc000+1024
	$3 = 0xffffc900017bc400

然后，根据前面得到的 super block 起始地址，直接映射磁盘上的 super block 到 `struct ext4_super_block` 数据结构中，

	crash> ext4_super_block 0xffffc900017bc400
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
	  s_mtime = 1464150337,
	  s_wtime = 1464150337,
	  s_mnt_count = 2,
	  s_max_mnt_count = 65535,
	  s_magic = 61267, /* 文件系统幻数 */

	  ...[snipped]...
	}

	crash> p /x 61267
	$5 = 0xef53 /* 文件系统幻数 */

而且，可以查看 `ext4_super_block` 的大小，

	crash7> ext4_super_block | grep SIZE
	SIZE: 1024

最后，用 `debugfs` 来检查 crash 查看的 super block 是否不是和 `debugfs` 一样准确，

	$ sudo debugfs /dev/sampleblk1 -R show_super_stats
	debugfs 1.42.9 (28-Dec-2013)
	Filesystem volume name:   <none>
	Last mounted on:          <not available>
	Filesystem UUID:          5c651ae8-bc3f-4fab-9e94-5b7d14c633f3
	Filesystem magic number:  0xEF53  /* 文件系统幻数 */
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
	Filesystem created:       Mon May 23 08:07:40 2016
	Last mount time:          Tue May 24 21:25:37 2016
	Last write time:          Tue May 24 21:25:37 2016
	Mount count:              2
	Maximum mount count:      -1
	Last checked:             Mon May 23 08:07:40 2016
	Check interval:           0 (<none>)
	Lifetime writes:          93 kB
	Reserved blocks uid:      0 (user root)
	Reserved blocks gid:      0 (group root)
	First inode:              11
	Inode size:	          128
	Default directory hash:   half_md4
	Directory Hash Seed:      31db6c7b-1f26-4ddb-87b9-2e9a9216ba8f
	Directories:              2
	 Group  0: block bitmap at 6, inode bitmap at 22, inode table at 38
	           482 free blocks, 53 free inodes, 2 used directories, 53 unused inodes
	           [Checksum 0x01c7]

### 4.4 查看 Group Descriptor

	crash> p /x 0xffffc900017bc000+1024+1024
	$6 = 0xffffc900017bc800

	crash> ext4_group_desc 0xffffc900017bc800
	struct ext4_group_desc {
	  bg_block_bitmap_lo = 6,  /* block bitmap at 6 */
	  bg_inode_bitmap_lo = 22, /* inode bitmap at block 22 */
	  bg_inode_table_lo = 38,  /* inode table at block 38 */
	  bg_free_blocks_count_lo = 482,
	  bg_free_inodes_count_lo = 53,
	  bg_used_dirs_count_lo = 2,
	  bg_flags = 4,
	  bg_exclude_bitmap_lo = 0,
	  bg_block_bitmap_csum_lo = 0,
	  bg_inode_bitmap_csum_lo = 0,
	  bg_itable_unused_lo = 53,
	  bg_checksum = 455,
	  bg_block_bitmap_hi = 0,
	  bg_inode_bitmap_hi = 0,
	  bg_inode_table_hi = 0,
	  bg_free_blocks_count_hi = 0,
	  bg_free_inodes_count_hi = 0,
	  bg_used_dirs_count_hi = 0,
	  bg_itable_unused_hi = 0,
	  bg_exclude_bitmap_hi = 0,
	  bg_block_bitmap_csum_hi = 0,
	  bg_inode_bitmap_csum_hi = 0,
	  bg_reserved = 0
	}

### 4.5 查看 inode table

	crash> p /x 0xffffc900017bc000+1024*38
	$8 = 0xffffc900017c5800

	crash> struct ext4_inode -x 0xffffc900017c5800
	struct ext4_inode {
	  i_mode = 0x0,
	  i_uid = 0x0,
	  i_size_lo = 0x0,
	  i_atime = 0x57431cbc,
	  i_ctime = 0x57431cbc,
	  i_mtime = 0x57431cbc,
	  i_dtime = 0x0,
	  i_gid = 0x0,
	  i_links_count = 0x0,
	  i_blocks_lo = 0x0,
	  i_flags = 0x0,

	$ sudo debugfs /dev/sampleblk1 -R 'bd 38'
	debugfs 1.42.9 (28-Dec-2013)
	0000  0000 0000 0000 0000 bc1c 4357 bc1c 4357  ..........CW..CW
	0020  bc1c 4357 0000 0000 0000 0000 0000 0000  ..CW............
	0040  0000 0000 0000 0000 0000 0000 0000 0000  ................


在 inode table 中定位某个 inode

	$ sudo touch /mnt/a
	$ ls -i /mnt/a
	12 /mnt/a

	$ sudo debugfs /dev/sampleblk1 -R 'show_inode_info a'
	debugfs 1.42.9 (28-Dec-2013)
	Inode: 12   Type: regular    Mode:  0644   Flags: 0x80000
	Generation: 603494144    Version: 0x00000001
	User:     0   Group:     0   Size: 0
	File ACL: 21    Directory ACL: 0
	Links: 1   Blockcount: 2
	Fragment:  Address: 0    Number: 0    Size: 0
	ctime: 0x5745313c -- Tue May 24 21:59:40 2016
	atime: 0x5745313c -- Tue May 24 21:59:40 2016
	mtime: 0x5745313c -- Tue May 24 21:59:40 2016
	EXTENTS:

	crash> ext4_inode | grep SIZE
	SIZE: 160
	crash> ext4_super_block.s_inode_size 0xffffc900017bc400
	  s_inode_size = 128

	crash> p /x 0xffffc900017bc000+1024*38+128*(12-1)
	$14 = 0xffffc900017c5d80
	crash> struct ext4_inode -x 0xffffc900017c5d80
	struct ext4_inode {
	  i_mode = 0x81a4,
	  i_uid = 0x0,
	  i_size_lo = 0x0,
	  i_atime = 0x5745313c,
	  i_ctime = 0x5745313c,
	  i_mtime = 0x5745313c,
	  i_dtime = 0x0,
	  i_gid = 0x0,
	  i_links_count = 0x1,
	  i_blocks_lo = 0x2,
	  i_flags = 0x80000,

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
