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

## 1. Idea

写 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 的时候突然意识到，为写这篇文章开发的 Sampleblk 块驱动，也可以被用来展示文件系统的 Disk Layout。
Sampleblk [day1 的源码](https://github.com/yangoliver/lktm/tree/master/drivers/block/sampleblk/day1)尽管只有 200 多行，但已经在其上可以创建各种文件系统。
由于 Sampleblk 是个 ramdisk，磁盘数据实际上都写在了驱动分配的内核内存里，因此可以很方便的使用 Linux Crash 工具来研究任意一种文件系统的磁盘格式，即 Disk layout。
本文将在 Sampleblk 块设备上创建 Ext4 文件系统，并利用 Linux Crash 工具来查看 Ext4 文件系统的磁盘格式。

## 2. Preparation

## 3. Ext4 Disk Layout

## 4. Extend Readings

* [Linux Block Driver - 1](http://oliveryng.net/2016/04/linux-block-driver-basic-1)
* [Linux File System - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1)
* [Linux File System - 2](http://oliveryang.net/2016/01/linux-file-system-basic-2)
* [Linux File System - 3](http://oliveryang.net/2016/02/linux-file-system-basic-3)
* [在Fedora 20环境下安装系统内核源代码](http://www.cnblogs.com/kuliuheng/p/3976780.html)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background)
* [Linux Crash White Paper (了解 crash 命令)](http://people.redhat.com/anderson/crash_whitepaper)
