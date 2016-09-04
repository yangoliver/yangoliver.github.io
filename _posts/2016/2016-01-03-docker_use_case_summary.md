---
layout: post
title: Docker Use Case Summary
description: 本文介绍Docker的主要应用场景。关键字：Docker，容器，Devops，Docker镜像，PaaS，CaaS，内核，Linux，IaaS，云计算，虚拟化，微架构。
categories: [Chinese, Software]
tags: [docker, virtualization, cloud, solaris]
---

>转载时请包含原文或者作者网站链接：<http://oliveryang.net>。

**Docker** 无疑是近两年来最火热的技术话题之一。而且落地速度之快也是大大出乎很多人的意料之外。
而在10年前就接触过 Solaris Container 技术的我，看到这种现象也不免疑惑:

> 为何 container 在出现十几年后，借助 Docker 火起来了？Docker 在古老的 container 技术基础上做了什么什么创新?

于是就有了研究Docker的想法, 虽然和目前工作无关。

随后一周内写出了[Docker Use Case Summary](https://github.com/yangoliver/mydoc/raw/master/share/docker_use_case_summary.pdf)
这个文档。里面总结了 9 个常见的 use case。因为是新手，可能理解并不充分和全面,
后续会随着认识加深不断更新这个文档。

总得看来，container 技术只是 Docker 的一个 building block 而已。Docker 重新定义和设计了 application 的 build,
ship, run 的方式，使这些环节无缝的和 container 结合在一起。Container 的 deploy, run, management 也出现了颠覆性
的改变。随着 vSphere Integrated Container，Hyper，Unikernel 技术和 Docker 技术的集成，
Docker 逐渐成为这些基础软件栈的入口点，和 container 之间的定位差别愈发凸显起来。

因此，Docker image 和 Docker engine 成为 Docker 技术在各种基础构件 (Container，VM，Unikernel) 之上构建的核心价值。

围绕着 Docker 技术，正在形成着一个庞大的云计算的生态系统。IaaS 和 PaaS 平台的开发者都纷纷把 Docker 技术纳入到
自己的解决方案之中。PaaS 在云计算技术发展中一直落后于 IaaS，而 Docker 很可能带来了又一轮 PaaS 技术的创新，使
得 PaaS 的解决方案得以广泛应用。

Cloud Computing 离我们越来越近了。在到达引爆点之前，工程师们得准备好啊。
