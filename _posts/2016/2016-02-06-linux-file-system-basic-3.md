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

   - amplefs_put_super

2. 解析 mount 的命令行参数

   samplefs_parse_mount_options

#### 1.2 编译和加载

### 2. 相关概念和接口

#### 2.1 Super Block

#### 2.2 mount 实例

### 3. 实验和调试

#### 3.1 文件系统 mount

#### 3.2 遍历 mount 实例

#### 3.3 查看 Super Block

### 4. 小结
