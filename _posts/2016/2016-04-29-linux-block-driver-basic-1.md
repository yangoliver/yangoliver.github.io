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

### 2. 模块初始化

#### 2.1 块设备注册

#### 2.2 磁盘创建和初始化

#### 2.3 块设备操作函数表

#### 3. 策略函数实现

##### 3.1 IO Requeust Queue

##### 3.2 IO Request

##### 3.3 BIO 结构

### 4. 试验

#### 4.1 模块引用问题解决

#### 4.2 创建文件系统

### 5. 延伸阅读

* [Using kdb/kgdb debug Linux kernel - 1](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-1/)
* [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/)
* [Debugging kernel and modules via gdb](https://github.com/torvalds/linux/blob/master/Documentation/gdb-kernel-debugging.txt)
* [Linux Crash Utility - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash Utility - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
