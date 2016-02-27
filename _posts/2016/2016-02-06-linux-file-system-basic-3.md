---
layout: post
title: Linux File System Basic - 3
description: Linux file system(文件系统)模块的实现和基本数据结构。关键字：文件系统，内核，samplefs，VFS，存储。
categories:
- [Chinese, Software]
tags:
- [file system, crash, kernel, linux, storage]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

TBD.

## 文件系统 mount 和 Super Block

Samplefs Day2 的代码涉及到了文件系统 mount 和 Super Block (超级块)的实现。
本文将以 [Day2 的代码](https://github.com/yangoliver/lktm/tree/master/fs/samplefs/day2)
为例，讲解相关概念。

### 1. Samplefs Day2

#### 1.1 源代码

与 Day1 相比，Day2 的实现增加了下面几个函数，

- samplefs_fill_super: 初始化 VFS Super Block。

  该回调在文件系统被 mount 时被调用。

  mount 在VFS文件系统的调用路径以系统调用 `sys_mount` 为起点，路径如下(内核版本3.19)，

		sys_mount->do_mount->do_new_mount->vfs_kern_mount->mount_fs

  在 VFS 层面，由于 samplefs 早已在模块加载时就向其注册了文件系统类型，
  因此 VFS 可以很方便查找到 samplefs 在 samplefs_fs_type 里注册的入口函数 samplefs_mount，
  而 samplefs_mount 使用了 mount_nodev 方法，并把 samplefs_fill_super 回调作为参数传递给 mount_nodev,

		samplefs_mount->mount_nodev

  mount_nodev 分配了新的 VFS Supoer Block 然后调用 samplefs_fill_super 回调做了如下几件事情，

  1. 分配 root inode
  2. 分配了属于 samplefs 模块的内存 Super Block: samplefs_sb_info，并让它在 VFS 层的 Super Block 指向它。
  3. 根据 root inode，分配 root dentry，作为 mount_nodev，也是 samplefs_mount 的最终返回值。
  4. 使用 load_nls_default() 函数初始化 samplefs 模块的内存 Super Block。
     主要用于 mount 时对不同编码字符集的支持, Linux NLS Kconfig 里有对 Native language support 的说明。
  5. 调用 samplefs_parse_mount_options 来解析 mount 时的选项参数。

- samplefs_parse_mount_options: 解析 mount 文件系统时的选项参数。

  这个函数的实现比较简单，值得说明的有两点，

  1. mount 时的选项参数是在 sys_mount 系统调用时从用户空间拷贝到内核内存中，
     再由 VFS 的代码通过 samplefs 的 mount 入口函数传入进来的。

  2. 解析后的选项参数保存在了 samplefs 模块的 Super Block：samplefs_sb_info 里。
     Samplefs 的 VFS Super Block 结构指向这个结构。

- samplefs_put_super: 释放 Super Block。


#### 1.2 编译和加载

编译 Day2 模块需要先编译 Linux 内核源代码。请参考
[Linux File System Basic - 2](http://oliveryang.net/2016/01/linux-file-system-basic-2/)。

Samplefs 的编译可以在 Linux 内核编译成功后，运行下面的命令单独编译，

	make M=/ws/lktm/fs/samplefs/day2

原来的 Day2 的代码是为 Linux 2.6 写的，在新内核 Linux 3.19 上会因为内核接口的变化引起编译错误。
请参考[针对新内核接口的 Patch](https://github.com/yangoliver/lktm/commit/dd2b5a7332ff61ee8a4ded3281616b0f77d6eddf#diff-2e79772ae929f397a8bb5817fc4e6c4f)
来查看这些内核接口的变化。有了这个新的 Patch，Day2 的模块可以成功编译了。

### 2. 相关概念和接口

#### 2.1 Super Block

#### 2.2 mount 实例

### 3. 实验和调试

#### 3.1 文件系统 mount

#### 3.2 遍历 mount 实例

#### 3.3 查看 Super Block

### 4. 小结
