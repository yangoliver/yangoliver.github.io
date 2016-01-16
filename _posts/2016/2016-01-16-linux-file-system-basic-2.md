---
layout: post
title: Linux File System Basic - 2
categories:
- [Chinese, Software]
tags:
- [fs, crash, kernel, linux, storage]
---


##1. 下载samplefs

简单文件系统(samplefs)是Steve French写的用于以下目的，

- 理解如和实现一个文件系统

- 在Linux OS上做文件系统的相关实验

- 学习文件系统的debug和tuning

所以，samplefs是一个教学目的的文件系统，源代码可以到[samba.org](http://svn.samba.org/samba/ftp/cifs-cvs/samplefs.tar.gz)
的SVN服务器上去下载。

本文的内容将基于[day1目录的源代码](https://github.com/yangoliver/lktm/tree/master/fs/samplefs/day1)展开。

文件系统的代码可以实现为一个独立的内核模块，也可以是被编译为内核的一部分。而samplefs day1的代码则展示了文件系统内核模块
的实现，主要包括以下几部分,

- Kconfig菜单

- Makefile

- 实现内核模块init和remove

  1. init_samplefs_fs

     函数实现了文件系统注册。初始化文件系统的名字，还有superblock的分配。

  2. exit_samplefs_fs

     释放了超级块，向内核取消了文件系统注册。


##2. 编译samplefs

编译模块前，先编译内核源代码。由于开发环境是Fedroa22，所以内核源代码的编译可以通过下载对应版本的源码rpm来完成。源码的下载
和编译过程参考了[在Fedora 20环境下安装系统内核源代码] (http://www.cnblogs.com/kuliuheng/p/3976780.html)这篇文章。

TBD.
