---
layout: post
title: Linux File System - 2
description: Linux file system(文件系统)模块的实现和基本数据结构。关键字：文件系统，内核，samplefs，VFS，存储。
categories: [Chinese, Software]
tags:
- [file system, crash, kernel, linux, storage]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

* content
{:toc}

### 1. 文件系统注册

本文将以Samplefs [day1的源代码](https://github.com/yangoliver/lktm/tree/master/fs/samplefs/day1)为例来说明文件系统注册的相关概念。

简单文件系统(samplefs)是Steve French写的用于教学目的的文件系统。它的设计初衷是帮助初学者理解如何实现一个文件系统，并且在Linux环境下对文件系统
如何debug和tunning。

Samplefs的源代码可以到 [samba.org](http://svn.samba.org/samba/ftp/cifs-cvs/samplefs.tar.gz)
的SVN服务器上去下载。

#### 1.1 源代码

文件系统的代码可以实现为一个独立的内核模块，也可以被编译为内核的一部分。而samplefs day1的代码则展示了文件系统内核模块
的实现，主要包括以下几部分,

- Kconfig菜单

- Makefile

- 实现内核模块init和remove

  1. init_samplefs_fs

     函数实现了文件系统注册。初始化文件系统的名字，还有superblock的分配。

  2. exit_samplefs_fs

     释放了超级块，向内核取消了文件系统注册。

整个实现中，file_system_type结构是关键数据结构，模块的代码去要初始化该结构里必要的成员。

#### 1.2 编译 Linux 内核

编译模块前，需要先编译内核源代码。由于开发环境是Fedroa22，所以内核源代码的编译可以通过下载对应版本的源码rpm来完成。Fedora源码
的下载和编译过程参考了[在Fedora 20环境下安装系统内核源代码](http://www.cnblogs.com/kuliuheng/p/3976780.html)这篇文章。

Samplefs需要修改fs/Kconfig文件。可以直接通过打
[Kconfig.diff patch](https://github.com/yangoliver/lktm/blob/master/fs/samplefs/Kconfig.diff)来修改。由于samplefs的代码不支
持我的3.19.8内核，所以做了一些[修改](https://github.com/yangoliver/lktm/commit/3f532c7b8fab0f275014eb097350dfc6d7663cef#diff-baf703407d18a8fc164164f39e33b3c9)。

然后在内核源代码顶层目录下运行，

	$make menuconfig

选择**File systems**，然后找到**Sample Filesystem (Experimental)**，选择**[M]**，表示编译成内核模块。最后返回保存设置。

运行`make all`后，内核编译开始，需要一直等待编译结束。

#### 1.3 编译 samplefs 模块

内核编译完成后，可以在同一目录下继续编译samplefs模块，

	$ make M=/ws/lktm/fs/samplefs/day1

由于samplefs是为早期内核版本开发的，因此直接编译会有错误。最主要的原因是数据结构file_system_type在新老内核版本中的定义被修改
了。原来结构体中的.get_sb被修改为.mount，接口和代码的实现都有所不同。为了支持3.19.8，需要重新实现.mount的函数，因此做了一些
[新的改动](https://github.com/yangoliver/lktm/commit/9488166625cd70248211e03024729d52a993048a)。
有了这个改动，内核模块的编译就可以成功了。

#### 1.4 加载 sampelfs

加载samplefs时，遇到了下面的错误，

	$ sudo insmod samplefs.ko
	insmod: ERROR: could not insert module samplefs.ko: Invalid module format

查看dmesg输出，得到下面的错误日志，

	[9781550.242445] samplefs: version magic '3.19.8 SMP mod_unload ' should be '3.19.8-100.fc20.x86_64 SMP mod_unload '

貌似正在运行的内核和当前内核源码不是完全匹配的，所以导致模块和内核版本不匹配问题。`modprobe -force`貌似可以解决这个问题，不
过不打算把模块copy到默认加载路径，所以用以下方式做了workaround，

* 打开当前内核源码的头文件，把UTS_RELEASE修改成为当前运行内核的版本字符串，

	$ vi include/generated/utsrelease.h

	#define UTS_RELEASE "3.19.8-100.fc20.x86_64"

重新编译模块，再次加载，终于成功。加载成功后内核日志有新的错误，

	[9782053.072278] samplefs: module license 'unspecified' taints kernel.
	[9782053.072282] Disabling lock debugging due to kernel taint
	[9782053.072364] samplefs: module verification failed: signature and/or required key missing - tainting kernel

显然，这是原有samplefs没有声明模块的License导致的，新内核对GPL License的检查越来越严厉了，连lock debug干脆都给关掉了。于是，
给代码增加[GPL Module License](https://github.com/yangoliver/lktm/commit/8a2779aaf0bbebd1f96930d16fdf7186d21baf5c)，错误消息
被解决。

至此，samplefs已经正确的加载到内核,

	$ lsmod | grep samplefs
	samplefs               12511  0

### 2. 相关概念和接口

#### 2.1 file_system_type - 文件系统类型结构

即然Linux支持同时运行不同的文件系统，那么必然要有一个数据结构来描述正在内核中运行的文件系统类型，这就是file_system_type结构，

	struct file_system_type {
		const char *name;		/* 文件系统名字*/
		int fs_flags;			/* 文件mount时用到的标志位*/
	#define FS_REQUIRES_DEV		1
	#define FS_BINARY_MOUNTDATA	2
	#define FS_HAS_SUBTYPE		4
	#define FS_USERNS_MOUNT		8	/* Can be mounted by userns root */
	#define FS_USERNS_DEV_MOUNT	16 /* A userns mount does not imply MNT_NODEV */
	#define FS_RENAME_DOES_D_MOVE	32768	/* FS will handle d_move() during rename() internally. */
		struct dentry *(*mount) (struct file_system_type *, int,	/* mount文件系统时调用的人口函数*/
			       const char *, void *);
		void (*kill_sb) (struct super_block *);	/* umount文件系统时调用的入口函数*/
		struct module *owner;	/* 指向这个文件系统模块数据结构的指针*/
		struct file_system_type * next;	/* 全局文件系统类型链表的下一个文件系统类型节点，应初始化为NULL */
		struct hlist_head fs_supers;	/* 本文件系统的所有超级款的链表表头*/

		struct lock_class_key s_lock_key;		/* LOCKDEP 所需的数据结构，lock debug特性打开才有用*/
		struct lock_class_key s_umount_key;		/* 同上*/
		struct lock_class_key s_vfs_rename_key;	/* 同上*/
		struct lock_class_key s_writers_key[SB_FREEZE_LEVELS];	/* 同上*/

		struct lock_class_key i_lock_key;	/* 同上*/
		struct lock_class_key i_mutex_key;	/* 同上*/
		struct lock_class_key i_mutex_dir_key;	/* 同上*/
	};

以上代码来自3.19.8-100.fc20的源代码，关键的结构成员都用中文做了注释。

那么samplefs day1的代码是如何写的呢？

	static struct file_system_type samplefs_fs_type = {
		.owner = THIS_MODULE,	/* 和所有Linux模块一样*/
		.name = "samplefs",		/* samplefs的名字*/
	#if LINUX_VERSION_CODE > KERNEL_VERSION(2,6,39)	/* 2.6.39后，mount文件系统入口函数是.mount, 以前是.get_sb */
		.mount = samplefs_mount,	/* 初始化mount的入口函数为samplefs_mount */
	#else
		.get_sb = samplefs_get_sb,	/* 老内核的入口函数初始化，可忽略*/
	#endif
		.kill_sb = kill_anon_super,	/* umount时入口函数，用内核默认函数释放超级块*/
		/*  .fs_flags */
	};

#### 2.2 VFS (Virtual Filesystem Switch)

由于Linux支持70多种不同的文件系统，那么必然就需要在架构上保证不同的文件系统的实现可以做到高效和简洁。VFS可以说很好的实现了这个目标，

* 向上的接口对用户程序提供统一一致的文件系统服务

  VFS是Linux文件系统的通用抽象层，包含了所有文件系统的所需要的公共部分，最大程度消除了文件系统的重复代码，让不同文件系统可以专注于自己的差异化实现。

* 向下的接口实现了让不同种类文件系统可以同时共存

  通过VFS的通用抽象层，不同文件系统之间消除了耦合性。不然可以同时存在并运行，而且一个文件系统的bug，不会扩散影响到另外的文件系统。提高的文件系统的
  可扩展性和健壮性。

因此，即使是实现一个最简单的文件系统，也不可能绕开VFS的API。

#### 2.3 注册和注销文件系统

Day1的源码里在module init和remove的入口函数里用到了如下VFS API，

	extern int register_filesystem(struct file_system_type *);
	extern int unregister_filesystem(struct file_system_type *);

这些API提供了向VFS注册和注销文件系统的基本功能。函数register_filesystem的实现代码非常简单，就是把它的输入，即文件系统类型结构(file_system_type)添加
到名称为file_systems的全局链表的尾部。这个全局链表的节点数据类型就是file_system_type本身。

正是因为这个函数，让上层的VFS代码可以在文件系统mount和umount操作可以直接通过这个链表上的结构去调用不同文件系统模块的具体实现。

#### 2.3 mount 文件系统

当用户调用mount命令去挂载文件系统时，VFS的代码将从file_systems链表找到对应类型的文件系统file_system_type结构，然后调用.mount入口函数。

mount入口函数参数说明如下，

	struct file_system_type *fs_type: 文件系统类型结构指针，samplefs已经做了部分的初始化。
	int flags: mount的标志位。
	const char *dev_name: mount文件系统时指定的设备名称。
	void *data: mount时指定的命令选项，通常是ascii码。

返回值，

	mount函数必须返回文件系统树的root dentry(根目录项)。在mount时超级块的引用计数必须增加，
	而且必须拿锁状态下操作。函数在失败时必须返回ERR_PTR(error)。

根据文件系统的类型，即fs_type，mount函数的参数可能会被解释成不同的含义。例如，
文件系统是基于块设备的，dev_name应该是块设备的名字。如果这个设备上包含文件系统，
它将会被打开，同时这个方法会根据磁盘文件系统的超级块内容，在内存中创建和初始化VFS Super Block(超级块)，
并且返回该文件系统在VFS中的root dentry。

通常，VFS为文件系统实现mount入口函数提供了如下三个不同的方法。这三个方法中除了新分配或者获取已经存在的VFS Super Block，
还可能进一步使用调用者实现指定的fill_super回调来初始化Super Block。因此，每个文件系统都需要实现fill_super函数回调。

- mount_bdev: mount存在于块设备之上的文件系统。

	struct dentry *mount_bdev(struct file_system_type *fs_type,
		int flags, const char *dev_name, void *data,
		int (*fill_super)(struct super_block *, void *, int));

  磁盘文件系统在内存中的超级块通常是由磁盘上存储的超级块构造或者与之紧密关联的。
  这类函数实现中，通常是同一个块设备返回相同的Super Block，不同的块设备返回不同的Super Block。
  这时fill_super在块设备首次被mount时才被调用。

- mount_nodev: mount没有后备设备(不存在于任何设备之上)的文件系统。

	struct dentry *mount_nodev(struct file_system_type *fs_type,
		int flags, void *data,
		int (*fill_super)(struct super_block *, void *, int));

  用于非磁盘文件系统。每次mount都会返回一个新的VFS Super Block。例如ramfs。
  这时fill_super总是被无条件调用。

- mount_single: mount可以在所有mount实例上全局共享的文件系统。

	struct dentry *mount_single(struct file_system_type *fs_type,
		int flags, void *data,
		int (*fill_super)(struct super_block *, void *, int));

  用于非磁盘文件系统。每次mount都使用同一个VFS Super Block。例如debugfs。
  这时fill_super只在第一次分配Super Block后被调用，用于首次初始化。

Samplefs不是磁盘文件系统，它使用了mount_nodev来实现mount入口函数，并且，
fill_super回调被初始化为samplefs_fill_super。

	static struct dentry *samplefs_mount(struct file_system_type *fs_type, int flags,
		const char *dev_name, void *data)
	{
		return mount_nodev(fs_type, flags, data, samplefs_fill_super);
	}

Day1的代码里samplefs_fill_super是空函数。这就意味着，Day1的实现里，
每次mount文件系统，都会调用samplefs_mount入口函数。在这个函数里，
mount_nodev总会分配一个新的samplefs在VFS层面上的Super Block。但是，
由于samplefs_fill_super是空函数，这些Super Block并没有初始化。

### 3. 实验和调试

如果利用crash，我们可以遍历文件系统的全局链表，并且找到samplefs的对应节点。若需要了解Linux Crash，可查看
[Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background)这篇文章。

* 首先，crash默认并不加载模块调式信息，因此在实验之前，需要手动加载samplefs模块，

		crash> mod -s samplefs /ws/lktm/fs/samplefs/day1/samplefs.ko
		     MODULE       NAME               SIZE  OBJECT FILE
		ffffffffa04ec040  samplefs           12511  /ws/lktm/fs/samplefs/day1/samplefs.ko
	
		crash> lsmod |grep samplefs
		ffffffffa04ec040  samplefs           12511  /ws/lktm/fs/samplefs/day1/samplefs.ko

* 然后，用crash去遍历文件系统类型的全局链表

  首先查看源代码，确定全局链表的符号，然后打印起始地址，

		crash> p file_systems
		file_systems = $9 = (struct file_system_type *) 0xffffffff81c87660 <sysfs_fs_type>

  没想到我的Fedora 20的VM上竟然有28个文件系统类型，不过大部分注册的文件系统是**特殊目的文件系统**。关于什么是特殊目的文件系统，请参考
  [Linux File System - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1)。

		crash> list file_system_type.next -s file_system_type.name 0xffffffff81c87660 | grep name | wc -l
		28

  遍历开始，有链表其实地址，.next是链表连接件，要查看的是.name，是可读的字符串，

		crash> list file_system_type.next -s file_system_type.name 0xffffffff81c87660
		ffffffff81c87660
		  name = 0xffffffff81a83554 "sysfs"
		ffffffff81c1b440
		  name = 0xffffffff81a5c060 "rootfs"
		ffffffff81c8d960
		  name = 0xffffffff81a2d869 "ramfs"
		ffffffff81c82840
		  name = 0xffffffff81a5c4b2 "bdev"
		ffffffff81c870c0
		  name = 0xffffffff81a521a3 "proc"
		ffffffff81c641c0
		  name = 0xffffffff81a7c140 "cgroup"
		ffffffff81c65500
		  name = 0xffffffff81a5a859 "cpuset"
		ffffffff81c6cac0
		  name = 0xffffffff81a8febc "tmpfs"
		ffffffff81cc5860
		  name = 0xffffffff81a8feb9 "devtmpfs"
		ffffffff81c8e0c0
		  name = 0xffffffff81a60a54 "debugfs"
		ffffffff81c91e60
		  name = 0xffffffff81a6a67e "securityfs"
		ffffffff81cddde0
		  name = 0xffffffff81ad7b6b "sockfs"
		ffffffff81c7a100
		  name = 0xffffffff81a5b8c1 "pipefs"
		ffffffff81c87a20
		  name = 0xffffffff81a5e6fb "configfs"
		ffffffff81c87b40
		  name = 0xffffffff81a5e83b "devpts"
		ffffffff81c88900
		  name = 0xffffffff81a5fbde "ext3"
		ffffffff81c88940
		  name = 0xffffffff81a5fbe3 "ext2"
		ffffffff81c88000
		  name = 0xffffffff81a5eeec "ext4"
		ffffffff81c8dc40
		  name = 0xffffffff81a60790 "hugetlbfs"
		ffffffff81c8e000
		  name = 0xffffffff81a607df "autofs"
		ffffffff81c8e100
		  name = 0xffffffff81a60a9a "pstore"
		ffffffff81c8fd60
		  name = 0xffffffff81a69ce6 "mqueue"
		ffffffff81c95d00
		  name = 0xffffffff81a6b00c "selinuxfs"
		ffffffffa0139460
		  name = 0xffffffffa012fc17 "rpc_pipefs"
		ffffffffa01b2360
		  name = 0xffffffffa01acbdb "nfsd"
		ffffffffa04c8200
		  name = 0xffffffffa04c2ac7 "nfs"
		ffffffffa04c8180
		  name = 0xffffffffa04c2ac2 "nfs4"
		ffffffffa04ec000
		  name = 0xffffffffa04eb024 "samplefs"

  Linux也提供了/proc/filesystems接口来查看所有注册的文件系统，

		$ cat /proc/filesystems | grep samplefs
		nodev   samplefs


* 最后，找到samplefs对应节点地址，打印结构内容

  可以看到，samplefs的节点就在上面输出的最后两行，由此可以打印它的file_system_type的结构内容，

		crash> struct file_system_type ffffffffa04ec000
		struct file_system_type {
		  name = 0xffffffffa04eb024 "samplefs",
		  fs_flags = 0,
		  mount = 0xffffffffa04ea000 <samplefs_mount>,	/* .mount 实现 */
		  kill_sb = 0xffffffff812142d0 <kill_anon_super>,
		  owner = 0xffffffffa04ec040 <__this_module>,	/* 指向了samplefs module的地址*/
		  next = 0x0,
		  fs_supers = {
		    first = 0x0	/* Day1的代码还没有初始化这个成员 */
		  },
		  s_lock_key = {<No data fields>},
		  s_umount_key = {<No data fields>},
		  s_vfs_rename_key = {<No data fields>},
		  s_writers_key = 0xffffffffa04ec038,
		  i_lock_key = {<No data fields>},
		  i_mutex_key = {<No data fields>},
		  i_mutex_dir_key = {<No data fields>}
		}

  我们也可以打印出samplefs的module数据结构，比如模块名称，模块text和data段的起始地址和大小，

		crash> struct module.name,module_core,core_size 0xffffffffa04ec040
		  name = "samplefs\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000"
		  module_core = 0xffffffffa04ea000 <samplefs_mount>
		  core_size = 12511


### 4. 小结

通过samplefs day1的源码和实验，我们可以对实现文件系统模块的一些基本概念有些了解。Linux内核一些特殊目的的文件系统也可以作为我们对照参考的例子。例如
ramfs只有不到600行c代码，分析和学习ramfs代码也可以加深对Linux VFS的接口和基本实现的理解。此外，也可以直接下载本文中使用的
[samplefs day1的全部代码和为新内核所做的修改](https://github.com/yangoliver/lktm/tree/master/fs/samplefs/day1)来做进一步的学习和实验。

### 5. 关联阅读

* [Linux File System - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1/)
* [在Fedora 20环境下安装系统内核源代码](http://www.cnblogs.com/kuliuheng/p/3976780.html)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background)
* [Linux Crash White Paper (了解 crash 命令)](http://people.redhat.com/anderson/crash_whitepaper)
