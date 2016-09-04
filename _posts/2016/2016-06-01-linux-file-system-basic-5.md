---
layout: post
title: Linux File System - 5
description: Linux file system(文件系统)模块的实现和基本数据结构。关键字：文件系统，内核，samplefs，VFS，存储。
categories: [Chinese, Software]
tags:
- [file system, driver, trace, kernel, linux, storage]
---

>转载时请包含原文或者作者网站链接：<http://oliveryang.net>

* content
{:toc}

## 1. 背景

本文继续 Samplefs 的源码介绍。[Day3 的源码](https://github.com/yangoliver/lktm/tree/master/fs/samplefs/day3)主要是在状态和调试方面的改进。

## 2. 代码

与 Day1 和 Day2 的代码相比，Day3 的实现非常简单。下面就其中的知识点做简单介绍。

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

Linux 驱动和内核模块可以给用户空间提供很多种接口。其中虚拟文件系统是常见的一种方式，例如 proc, sysfs, debugfs 等。

首先 `proc_mkdir` 和 `proc_create` 可以用来创建 proc 文件系统的目录和文件。Day3  代码如下，

	void sfs_proc_init(void)
	{
		proc_fs_samplefs = proc_mkdir("fs/samplefs", NULL);
		if (proc_fs_samplefs == NULL)
			return;

		proc_create("DebugData", 0, proc_fs_samplefs,
		    &samplefs_debug_data_proc_fops);
	}

其中 `proc_mkdir` 返回 `struct proc_dir_entry` 类型的变量，

	static struct proc_dir_entry *proc_fs_samplefs;

而调用 `proc_create` 在 `fs/samplefs` 目录下创建 `DebugData` 时，该调用还须声明 `struct file_operations`，

	static const struct file_operations samplefs_debug_data_proc_fops = {
		.owner      = THIS_MODULE,
		.open       = samplefs_debug_data_proc_open,
		.read       = seq_read,
		.llseek     = seq_lseek,
		.release    = single_release,
	};

`struct file_operations` 的 `.open` 方法如下，

	static int samplefs_debug_data_proc_open(struct inode *inode, struct file *file)
	{
		return single_open(file, samplefs_debug_data_proc_show, NULL);
	}

该函数通过使用 `single_open` 时指定 `show()` 方法来实现了下面的最简函数，

	static int samplefs_debug_data_proc_show(struct seq_file *m, void *v)
	{
		seq_puts(m,
				"Display Debugging Information\n"
				"-----------------------------\n");

		return 0;
	}

可以看到，当该 proc 文件每次被打开时，这个 `show()` 方法就会被调用一次。

在模块卸载前，可以调用 `remove_proc_entry` 来删除模块加载时创建的 proc 文件。

	void sfs_proc_clean(void)
	{
		if (proc_fs_samplefs == NULL)
			return;

		remove_proc_entry("DebugData", proc_fs_samplefs);
		remove_proc_entry("fs/samplefs", NULL);
	}

[Documentation/filesystems/seq_file.txt](https://github.com/torvalds/linux/blob/master/Documentation/filesystems/seq_file.txt) 里给出了上述相关接口的用法和说明。
而在其 `The extra-simple version` 这节里，就介绍了用 `single_open` 做最简的 proc 文件显示的实现。

## 4. 实验


模块参数可以通过 `insmod` 命令指定，Day3 的源码对模块参数做了检查，超过 `10` 的数值会被设置成 `10`，

	$ sudo insmod /home/yango/ws/lktm/fs/samplefs/day3/samplefs.ko sample_parm=9000

	[96287.090137] init samplefs
	[96287.090143] sample_parm 9000 too large, reset to 10

另外 `modinfo` 可以给出模块的详细信息，包括源码中描述的模块参数信息，

	$ modinfo /home/yango/ws/lktm/fs/samplefs/day3/samplefs.ko
	filename:       /home/yango/ws/lktm/fs/samplefs/day3/samplefs.ko
	license:        GPL
	srcversion:     A7EB3525B6F9C78912A2FDE
	depends:
	vermagic:       4.6.0-rc3+ SMP mod_unload modversions
	parm:           sample_parm:An example parm. Default: x Range: y to z (int)

Day3 的代码演示了在 `/proc/fs/samplefs/DebugData` 打印 debug 信息的方式，

	$ cat /proc/fs/samplefs/DebugData
	Display Debugging Information
	-----------------------------

我们利用 [perf-tools 的 kprobe](https://github.com/brendangregg/perf-tools/blob/master/kernel/kprobe) 可以查看该文件的 `open` 的 backtrace，

	$ sudo ./kprobe -s 'p:myprobe single_open'
	Tracing kprobe myprobe. Ctrl-C to end.
	             cat-25939 [000] d... 297059.599989: myprobe: (single_open+0x0/0xb0)
	             cat-25939 [000] d... 297059.600000: <stack trace>
	 => proc_reg_open
	 => do_dentry_open
	 => vfs_open
	 => path_openat
	 => do_filp_open
	 => do_sys_open
	 => SyS_open
	 => do_syscall_64
	 => return_from_SYSCALL_64
	^C
	Ending tracing...

也可以查看 `samplefs_debug_data_proc_show` 的 backtrace，

	$ sudo ./kprobe -s 'p:myprobe samplefs_debug_data_proc_show'
	Tracing kprobe myprobe. Ctrl-C to end.
	             cat-25930 [000] d... 296975.005899: myprobe: (samplefs_debug_data_proc_show+0x0/0x20 [samplefs])
	             cat-25930 [000] d... 296975.005915: <stack trace>
	 => proc_reg_read
	 => __vfs_read
	 => vfs_read
	 => SyS_read
	 => do_syscall_64
	 => return_from_SYSCALL_64
	^C
	Ending tracing...

## 5. 延伸阅读

* [Linux File System - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1)
* [Linux File System - 2](http://oliveryang.net/2016/01/linux-file-system-basic-2)
* [Linux File System - 3](http://oliveryang.net/2016/02/linux-file-system-basic-3)
* [Linux File System - 4](http://oliveryang.net/2016/05/linux-file-system-basic-4)
* [在Fedora 20环境下安装系统内核源代码](http://www.cnblogs.com/kuliuheng/p/3976780.html)
* [Dynamic Debug by Jason Baron](https://www.kernel.org/doc/ols/2009/ols2009-pages-39-46.pdf)
* [Documentation/dynamic-debug-howto.txt](https://github.com/torvalds/linux/blob/master/Documentation/dynamic-debug-howto.txt)
* [Documentation/filesystems/seq_file.txt](https://github.com/torvalds/linux/blob/master/Documentation/filesystems/seq_file.txt)
