---
layout: post
title: VM Backup Basic - 1
description: 虚拟机备份的介绍。关键字：VADP, Data protection, 数据保护，虚拟化，虚拟机，备份，恢复，VMFS，Volume。
categories:
- [Chinese, Software]
tags:
- [backup, data protection, virtual machine, virtualization, storage, cloud]
---

尽管文章的标题是VM Backup，但本篇文章只限于VMWare vShpere平台的VM Backup解决方案。

##1. VM那点儿事儿

解释什么是[Virtual Machine](https://en.wikipedia.org/wiki/Virtual_machine)的工作就交给万能的维基百科了。这里要说的一些概念
都是帮助理解VM Backup的，所以大都是VMWare虚拟化技术里存储相关的概念。我们按照自下而上的顺序来一一介绍，

- **LUN(Logical Unit Number)**

  [LUN](https://en.wikipedia.org/wiki/Lun)(逻辑单元编号)最早由SCSI协议引入，是SCSI总线协议寻址的设备地址。后来越来越多的被
  引申为Logical Disk(逻辑磁盘)或者Logical Volume(逻辑卷)。

  一个LUN可以由多个硬盘组成。任何外部的磁盘阵列都可以把多个物理盘划分到一个LUN里。从主机的角度看，一个LUN就是一块物理硬盘。
  可以说LUN就是外置存储设备对物理硬盘的虚拟化。

- **VMFS(Virtual Machine File System)**

  VMware vSphere VMFS不但支持VMFS Volume管理，而且同时还是一种高性能的Cluster File System，并专为虚拟机优化。

  1. **VMFS Volume**

     在VMWare的环境里，本地或者外部的存储一旦划分出了LUN，它就可以在这之上创见VMFS Volume。一个VMFS Volume通常只包含一个LUN，
	 但是也可以由多个VMFS Extent组成，每个VMFS Extent都是一个LUN。

  2. **Cluster File System**

     [Linux File System Basic - 1](http://oliveryang.net/2016/01/linux-file-system-basic-1/)这篇文章里，涉及到Cluster FS的
	 分类，而VMFS就属于Shared-disk文件系统这种架构。这就意味着，VMFS可以借助共享存储，如NAS，SAN存储，来实现多个VMware
     vSphere主机对同一文件系统的并发读写操作。而传统的本地文件系统，如Ext4，XFS，是无法允许多个主机同时mount和读写同一文件
	 系统的。

     正因为VMFS是集群文件系统，才使得虚拟机可以跨越单个物理机范围去扩展。可以说VMFS是VM快照，精简配置(Thin Provision)，VM的
     热迁移(VM vMotion), DRS(Distributed Resource Scheduler), HA(High Availability)，Storage vMotion等一系列重要特性的基础。

- **Datastore**

  Datastore是VMWare存储里抽象出的一个概念，用于存储虚拟机文件(Virtual Machine Files)。VMWare文档里是这么描述的，

  <pre>Datastores are logical containers, analogous to file systems, that hide
  specifics of each storage device and provide a uniform model for storing
  virtual machine files.</pre>

  说直白一点，Datastore就是VMWare为虚拟机提供的存储抽象，目前VMWare可以在下面几种文件系统和卷(Volume)上建立Datastore,

  1. **VMFS Datastore**

     VMFS Datastore需要在LUN之上创建VMFS Volume和文件系统。

     VMFS可以用于在服务器的DAS上创建只为本地虚拟机服务的文件系统，也可以用于在传统共享存储之上，如SAN(FC，iSCSI)，来创建允许
     多个vSphere主机上的不同虚拟机共享的集群文件系统。

  2. **NFS Datastore**

     直接使用第三方的NFS文件系统服务或者存储设备。

     在虚拟化时代，块接口访问方式大行其道，NFS Datastore显然不如其它方式更受用户的欢迎。

  3. **VSAN(VMWare Virtual SAN) Datastore**

     在VSAN的分布式对象文件系统上建立Datastore。

     VMWare全新的Cluster File System，和VMFS不同，它不需要在共享存储上建立文件系统集群。而是真正的基于DAS来建立的分布式文件
	 系统。关于VSAN的信息，可以查看[VSAN use case summary](http://oliveryang.net/2016/01/vsan-use-case-summary/)这篇文章。

  4. **VVol(VMWare Virtual Volume) Datastore**

     在第三方外置存储提供的VVol卷上创建Datastore。

     VVol是为第三方外置存储提供的软件定义解决方案。VM可以在VVol之上创建自己的Virtual Datastore。VVol和VSAN都是VMWare推出的
	 软件定义存储解决方案。只不过针对不同的用户需求和市场。VSAN作为HCI架构的VMWare原生存储方案，将会是未来发展的主方向。

  大多数情况下，VMWare建议一个Volume里只包含一个LUN。这时，Datastore和Volume是对等的关系。

- **Virtual Machine Files**

  虚拟机就是由内存里的数据和存在Datastore里的一组文件来共同组成的。在VMWare vSphere里，共有11种不同扩展名的虚拟机文件。其中
  最关键的要数下面几种，

  1. *.vmx 文件，需用存储虚拟机的配置。
  2. *.vmdk文件，虚拟磁盘文件，在虚拟机中被Guest OS识别为块设备。
  3. *.nvram文件，存放虚拟机BIOS和EFI固件的配置信息。
  4. *.log文件，虚拟机的关键活动日志，用于debug。
  5. *.vswp文件，存放虚拟机的虚拟内存交换数据。
  6. *.vmsd和*.vmsn，存放虚拟机的快照元数据和数据。

##2. VM Backup的前世

未完，待续

##3. VM Backup之今生

未完，待续
