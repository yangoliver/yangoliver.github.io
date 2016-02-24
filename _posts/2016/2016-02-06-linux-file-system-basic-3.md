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

与 Day1 相比，Day2 的实现增加下面两个主要功能，

1. 填充和释放 Super Block

   - samplefs_fill_super

   - samplefs_put_super

2. 解析 mount 的命令行参数

   samplefs_parse_mount_options

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
