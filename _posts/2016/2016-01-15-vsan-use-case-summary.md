---
layout: post
title: VSAN use case summary
description: VMWare Virtual SAN的基本概念和使用场景介绍。关键字：VSAN, 软件定义存储，Hyperscale，虚拟化，软件定义数据中心。
categories: [Chinese, Software]
tags:
- [storage, virtualization, cloud]
---

>本文首发于<http://oliveryang.net>，转载时请包含原文或者作者网站链接。

##1. 关于VSAN的一些概念

这里的VSAN是指**VMWare Virtual SAN**。它是VMWare公司的分布式存储产品。通过内置于VMWare vSphere Hypervisor内核中实现了基于服务
器和**DAS(Direct Attach Storage)**的分布式存储。

VSAN是**Server SAN**的一种形态。提起Server SAN，不得不提起**SDS(Software Defined Storage)**。而提起SDS，必然要与
**Software Based Storage**有所区别。

Software Based Storage是指那些基于**Commodity Hardware**(x86)和安装在这硬件之上的存储软件栈来组成的存储系统。SDS的存储首先是
Software Based Storage。但更重要的是，SDS存储更强调支持和提供外部的应用软件的编程控制的API。没有为应用设计的控制API的话，就
不是真正的软件定义存储。

一些传统存储厂商，例如EMC, 通过把**Control Panel**集中起来，对应用提供统一的编程控制API，也实现了SDS。**EMC Viper**就是这样
的例子。不但EMC自己的存储，还有第三方厂商的存储都可以被Viper驱动起来。为此，EMC还把Viper开源，发起了
**[CoprHD](https://coprhd.github.io/)**项目。然而，这些存储在Data Panel上并没有形态上的改变，例如基于
**SAN(Storage Aera Network)**
的存储，依旧是通过**FC(Fiber Channel)**或者**iSCSI**协议来和服务器连接。

而Server SAN作为SDS的一种，就更为激进一些。不但提供Control Panel的应用驱动接口，而且还在**Data Panel**层面上做了彻底的革新。
通过把Commodity的x86 server和server上直接相连的SSD和HDD等硬件，利用以太网技术互联起来，再其上搭建分布式存储系统，从而实现和
过去SAN存储类似的数据存储服务。

**Hyperscale**，**SDS**，**Flash**成为催化Server SAN诞生的主要技术。
**Hyerscale**或者**Webscale**就是特指类似Google, Amazon之类互联网公司技术架构的数据中心的一类基础设施，通常有以下特点，

* 基于x86服务器和高速以太网互联

* 通过虚拟化(Virtualization)将各种硬件资源池化，再通过软件定义(SDN,SDS)控制和分配硬件资源。

* 以Cloud Computing的方式把基础设施以服务的方式提供出去。

  用户通过这些云服务获得了Scale Out，弹性，自动化，高可用(HA)的好处。

因此, Hyperscale或者Webscale就是云计算基础设施的基本要求。也成为Server SAN的重要基础。

Server SAN的实现架构又存在两种截然不同的方式,

* 一种是有独立的存储集群，支持独立的水平扩展。

  这类存储的代表就是**EMC Scale IO**。

* 另一种就是计算，存储，网络彻底的融合，也叫做HCI**(Hyper-converged Infrastructure)**，超融合架构。

VMWare Virtual SAN就是典型的HCI架构的软件定义存储产品。Nutanix也属于这类产品。
为了区别于其它HCI的Server SAN产品，VMWware把VSAN又叫做**Hypervisor-converged**，标榜自己的实现是在Hypervisor内核里，IO
路径短，实现比较高效。

HCI架构的集群里，每个集群节点都可以部署主机VM，或者承担存储，网络业务，极大的简化了数据中心的管理。在私有云里，VMWare把HCI
作为SDDC(软件定义数据中心)的基础架构。

##2. VSAN的Use Case

从产品形态上看，VSAN的解决方案很灵活，主要有以下两种形态，

- Software，作为vSphere的存储模块

  VMWare Virtual San完全和vSphere绑定在一起，用户购买软件Lisense，安装到VMWare认证的x86服务器上。

- Appliance，即一体机。是软件和硬件集成的方案。

  集成方案里，因为面向的市场不同，VMWare围绕自己的软件栈推出了两套规范，

  1. EVO:RAIL

     硬件是2U内置4个独立节点的一体机。
     软件上搭载基本的VSAN软件栈，vSphere，VSAN，EVO:RAIL engine。

  2. EVO:RACK (EVO:SDDC)

     Rack Scale的解决方案。硬件包括服务器，网络交换机，DAE(Disk Array Enclosure)。
     软件上搭载了全套的云计算软件栈，包括vCloud Suite, NSX, EVO SDDC manager。

从用户业务场景(Use Case)来看，VSAN和一般的HCI软硬件主要在以下领域满足用户的需求，

1. VDI(Virtual Desktop Infrastructure)

2. ROBO(Remote Office Branch Office)

3. DevOPs(Dev & test platform)

4. ITOPs(Management cluster)

5. DMZ Isolation Deployment

6. Data Protection Target

7. Data Analytics(Big Data)

8. Mission Critical Application(Production)

9. DR(Disater Recovery)

10. SDDC IaaS use case(Data Center Cosolidation)

前7个Use Case基本上对存储的性能和稳定性要求都不是很高。第8个Use Case则对存储的性能和稳定性有很高的要求。
而第9和第10的Use Case不但对性能和稳定性有很高要求，而且需要一个Data Center级别的完整解决方案。要真正渗透到全部用户场景，
VSAN还有很长的路要走。

##3. 进一步了解

作为VMWare的SDS解决方案，VSAN的应用会变得越来越广泛。随着VSAN的技术和市场越来越成熟，有理由相信，在企业私有云数据中心里，
VSAN会变成VMWare虚拟化技术的主流存储平台。
我在[VSAN TOI part1](https://github.com/yangoliver/mydoc/blob/master/share/vsan_toi_part1.pdf)文档里收集了与VSAN产品相关的
一些基本信息，希望可以作为了解VSAN产品的一个好的开始。
