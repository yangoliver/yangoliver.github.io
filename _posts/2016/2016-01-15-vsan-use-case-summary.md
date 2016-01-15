---
layout: post
title: VSAN use case summary
categories:
- [Chinese, Software]
tags:
- [storage, virtualization, cloud]
---


##1. 关于VSAN的一些概念

这里的VSAN是指VMWare Virtual SAN。它是VMWare公司的分布式存储产品。通过内置于VMWare vSphere Hypervisor内核中实现了基于服务器
和DAS(Direct Attach Storage)的分布式存储。

VSAN是Server SAN的一种形态。提起Server SAN，不得不提起SDS(Software Defined Storage)。而提起SDS，必然要与Software Based
Storage有所区别。

Software Based Storage是指那些基于Commodity Hardware(x86)和安装在这硬件之上的存储软件栈来组成的存储系统。SDS的存储首先是
Software Based Storage。但更重要的是，SDS存储更强调支持和提供外部的应用软件的编程控制的API。没有为应用设计的控制API的话，就
不是真正的软件定义存储。

一些传统存储厂商，例如EMC, 通过把Control Panel集中起来，对应用提供统一的编程控制API，也实现了SDS。EMC Viper就是这样的例子。
不但EMC自己的存储，还有第三方厂商的存储都可以被Viper驱动起来。为此，EMC还把Viper开源，发起了
[CoprHD](https://coprhd.github.io/)项目。然而，这些存储在Data Panel上并没有形态上的改变，例如基于SAN (Storage Aera Network)
的存储，依旧是通过FC(Fiber Channel)或者iSCSI协议来和服务器连接。

而Server SAN作为SDS的一种，就更为激进一些。不但提供Control Panel的应用驱动接口，而且还在Data Panel层面上做了彻底的革新。通过
把Commodity的x86 server和server上直接相连的SSD和HDD等硬件，利用以太网技术互联起来，再其上搭建分布式存储系统，从而实现和过去
SAN存储类似的数据存储服务。

Hyperscale，SDS，Flash成为催化Server SAN诞生的主要技术。
Hyerscale或者Webscale就是特指类似Google, Amazon之类互联网公司技术架构的数据中心的一类基础设施，通常有以下特点，

* 基于x86服务器和高速以太网互联

* 通过虚拟化(Virtualization)将各种硬件资源池化，再通过软件定义(SDN,SDS)控制和分配硬件资源。

* 以Cloud Computing的方式把基础设施以服务的方式提供出去。

  用户通过这些云服务获得了Scale Out，弹性，自动化，高可用(HA)的好处。

因此, Hyperscale或者Webscale就是云计算基础设施的基本要求。也成为Server SAN的重要基础。

Server SAN的实现架构又存在两种截然不同的方式,

* 一种是有独立的存储集群，支持独立的水平扩展。

  这类存储的代表就是EMC Scale IO。

* 另一种就是计算，存储，网络彻底的融合，也叫做HCI(Hyper-converged Infrastructure)，超融合架构。

  VMWare Virtual SAN就是典型的HCI架构的软件定义存储产品。Nutanix也属于这类产品。

HCI架构的集群里，每个集群节点都可以部署主机VM，或者承担存储，网络业务，极大的简化了数据中心的管理。在私有云里，VMWare把HCI
作为SDDC(软件定义数据中心)的基础架构。

##2. VSAN的Use Case

TBD
