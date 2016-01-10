---
layout: post
title: Linux File System Basic - 1
categories:
- [Chinese, Software]
tags:
- [fs, kernel, linux, storage]
---


##1. 什么是文件系统

直接引用来自[维基百科文件系统的定义](http://en.wikipedia.org/wiki/Filesystem)，

<pre>A file system is a set of abstract data types that are implemented for the storage,
hierarchical organization, manipulation, navigation, access, and retrieval of data.</pre>

文件系统就是一套抽象的数据类型，实现了数据的存储，层级组织，操作，浏览，访问和取回。

##2. 文件系统分类

Linux恐怕是内置支持文件系统最多的操作系统了。Linux v4.4源代码里fs路径下的文件系统目录多达71个,

	$ pwd
	/ws/linux/fs
	$ ls -dl */ | wc -l
	71

###2.1 文件系统的架构

按照文件系统的架构，文件系统大致上可以分为以下几类，

- Local file systems

  即本地文件系统。典型的例子有Ext4, Btrfs, XFS, ZFS等。

  通常是在主机本地可见的存储介质上才能工作的文件系统。此类文件系统本身没有网络访问的能力。因此，如需访问远程
  介质，需要接触底层协议(如iSCSI, Fiber Channel)才能管理和访问数据。

  Linux上的本地文件系统很容易支持POSIX语义的文件API。


- Special purpose file systems

  即特殊目的文件系统。
 
  1. Pseudo and virtual file systems

     实现操作系统内核的状态查询，管理控制，和文件抽象功能。例如，procfs, sysfs，tmpfs, debugfs, devfs。
     实现某种开发框架。例如FUSE(Filesystem in Userspace)提供了一种在用户空间开发文件系统的通用机制。
     此外，由于近来Docker为代表的容器技术的兴起，使verlayFS，Aufs这类支持对底层多个本地文件系统做union mount的
     文件系统技术得以广泛应用。

  2. Cryptographic file systems
	
     专门用于文件系统级别的数据安全加密用途。例如，eCryptfs, SSHFS。

- Network file systems

  即网络文件系统。例如，NFS，CIFS(SMB)。

  此类文件系统被设计为client-server结构。客户端的文件系统通过提供远程文件的访问协议，来访问服务端的文件系统。

  网络文件系统一般很难支持完整的POSIX语义的文件访问。例如NFS文件的客户端可能缓存文件，导致数据在其它客户端或者服务端不
  不同步的问题。另外，NFSv3及以前版本是无状态的协议，并不支持POSIX fcntl locks。NFS的文件锁是通过Network Lock Manager
  (lockd后台进程) 这个独立程序实现的。直到NFSv4改为有状态协议，才实现了文件锁，不需要NLM协同工作了。

  针对本地文件系统开发和测试的应用，在网络文件系统上运行可能会有不同的行为，需要特别的处理。

  NAS(Network Attach Storage)存储是外置存储设备的一大类，其中NFS和CIFS是支持的主要访问协议。

- Clustered file systemas

  即集群文件系统。引用集群文件系统在维基百科的定义如下，

  <pre>A clustered file system is a file system which is shared by being simultaneously mounted
  on multiple servers.</pre>

  同一文件系统能否在多个主机上被同时挂载使用是集群文件系统的本质。根据架构上的差异，集群文件系统又被分为以下两大类，

  1. Shared-disk file systems

     即共享磁盘的文件系统。这架构的Block级别的访问是集中共享式的。所有文件系统的主机通过同步和锁原语访问同一个Block Storage。

     通常，块存储的共享是通过SAN(Storage Area Network)来实现共享的。

     这一领域代表性的实现有，IBM的GPFS，Oracle的OCFS，中科蓝鲸的BWFS，Red Hat的GFS(Global File System)。

  2. Distributed file systems

  	 即分布式文件系统。名字有些混淆。但和Share-disk类型的最大区别的，分布式文件系统的Block Storage不需要共享。每个节点都拥有
	 自己私有的Block Storage。但文件系统集群对使用者依旧提供统一的视图，即全局的命名空间(Global Name Space)。

     分布式文件系统可以利用廉价的DAS(Direct Attach Storage)来架构一个高性能的文件集群。特别是当万兆以太网和Flash/SSD技术在数
     据中心变得越来越普及，DAS做分布式文件系统的优势越来越明显。

     典型的分布式文件系统有Apache HDFS，Google的GFS(Google File System), Redhat的Ceph和Glusterfs，Lustre，微软的DFS,
     EMC Isilon的OneFS。

###2.2 存储介质和使用场景

按照存储介质和使用场景的不同，文件系统也可以划分为以下类型，

* Disk file systems

  基于磁盘(HDD)特性设计的文件系统。例如，Ext4, UFS, XFS 

* Optical discs file systems

  基于光盘特性设计的文件系统。例如，ISO 9660, UDF(Universal Disk Format)。

* Flash file systems

  基于Flash/SSD特性的文件系统。例如，JFFS2, YAFFS, F2FS.
  传统的磁盘文件系统也可用于SSD，但是由于SSD的一些独有特性，并不能发挥出SSD的性能优势。
  因此，这类文件系统一般针对SSD的硬件特性，GC，Wear Leveling等做了特别的优化和设计上的考虑。

* Tape file systems

  基于磁带特性设计的文件系统。例如，LTFS(Linear Tape File System)。

* Database file systems

  为数据库使用场景特别优化的文件系统。例如，DBFS(Oracle Database file system)。

* Transactional file systems

  为支持多个文件操作的原子性设计的文件系统。例如, Transactional NTFS，目前多为研究实验性质。
	
以上内容在互联网上已有不少论述，在此不一一赘述。
