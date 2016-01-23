---
layout: post
title: VM Backup Basic - 1
description: 虚拟机备份的介绍。关键字：VADP, Data protection, 数据保护，虚拟化，虚拟机，备份，恢复，VMFS，Volume。
categories:
- [Chinese, Software]
tags:
- [backup, data protection, virtual machine, virtualization, storage, cloud]
---

尽管文章的标题是VM Backup，但本篇文章只讨论VMWare vShpere平台的VM Backup解决方案。

##1. VM那点儿事儿

解释什么是[Virtual Machine](https://en.wikipedia.org/wiki/Virtual_machine)的工作就交给万能的维基百科了。这里要说的一些概念
都是帮助理解VM Backup的，所以大都是VMWare虚拟化技术里存储相关的概念。我们按照自下而上的顺序来一一介绍，

- **LUN(Logical Unit Number)**

  [LUN](https://en.wikipedia.org/wiki/Lun)(逻辑单元编号)最早由SCSI协议引入，是SCSI总线协议寻址的设备地址。后来越来越多的被
  引申为Logical Disk(逻辑磁盘)或者Logical Volume(逻辑卷)。

  一个LUN可以由多个硬盘组成。Linux的LVM，或者任何外部的磁盘阵列都可以把多个物理盘划分到一个LUN里。从主机的角度看，一个LUN就
  是一块物理硬盘。可以说LUN就是卷管理软件或者外置存储设备对物理硬盘的虚拟化。

- **VMFS Volume**

  在VMWare的环境里，本地或者外部的存储一旦划分出了LUN，它就可以在这之上创见VMFS Volume。一个VMFS Volume通常只包含一个LUN，但
  是也可以由多个VMFS Extent组成，每个VMFS Extent都是一个LUN。

- **VMFS(Virtual Machine File System)**

  VMware vSphere VMFS不但支持VMFS Volume管理，而且同时还是一种高性能的Cluster File System，并专为虚拟机优化。在
  [Linux File System Basic - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1/)这篇文章里，涉及到Cluster FS的分类，
  而VMFS就属于Shared-disk文件系统这种架构。这就意味着，VMFS可以借助共享存储，如NAS，SAN存储，来实现多个VMware vSphere主机对
  同一文件系统的并发读写操作。而传统的本地文件系统，如Ext4，XFS，是无法允许多个主机同时mount和读写同一文件系统的。

  正因为VMFS是集群文件系统，才使得虚拟机可以跨越单个物理机范围去扩展。可以说VMFS是VM快照，精简配置(Thin Provision)，VM的热
  迁移(VM vMotion), DRS(Distributed Resource Scheduler), HA(High Availability)，Storage vMotion等一系列重要特性的基础。

- **Datastore**

  Datastore是VMWare存储里抽象出的一个概念，VMWare文档里是这么描述的，

  <pre>Datastores are logical containers, analogous to file systems, that hide
  specifics of each storage device and provide a uniform model for storing
  virtual machine files.</pre>

  说直白一点，Datastore就是VMWare为虚拟机提供的存储抽象，这个logical container可以支持下面这些文件系统，

  1. VMFS文件系统
  
     VMFS文件系统需要在LUN之上创建VMFS Volume和文件系统。

  2. NFS文件系统

     直接使用第三方的NFS文件系统服务或者存储设备。


未完，待续

##2. VM Backup的前世

未完，待续

##3. VM Backup之今生

未完，待续
