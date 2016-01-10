---
layout: post
title: Docker Use Case Summary
categories:
- [Chinese, Software]
tags:
- [docker, virtualization, cloud]
---

Docker无疑是近两年来最火热的技术话题之一。而且落地速度之快也是大大出乎很多人的意料之外。
而在10年前就接触过Solaris Container技术的我，看到这种现象也不免疑惑:

<pre>为什么container在10年后借助Docker火起来了？Docker在古老的container技术基础上做了什么什么创新?</pre>

于是就有了研究Docker的想法, 虽然和目前工作无关。

随后一周内写出了[Docker Use Case Summary](https://github.com/yangoliver/mydoc/raw/master/share/docker_use_case_summary.pdf)
这个文档。里面总结了8个常见的use case。因为是新手，可能理解并不充分和全面,
后续会随着认识加深不断更新这个文档。

总得看来，container技术只是Docker的一个building block而已。Docker重新定义和设计了application的build,
ship, run的方式，使这些环节无缝的和container结合在一起。Container的deploy, run, management也出现了颠覆性
的改变。

因此，Docker image和Docker engine成为Docker这个技术在Container之上构建的核心价值。

另外，Docker技术之上正在构建一个庞大的云计算的生态系统。IaaS和PaaS平台的开发者都纷纷把Docker技术纳入到
自己的解决方案之中。PaaS在云计算技术发展中一直落后于IaaS，而Docker很可能带来了又一轮PaaS技术的创新，使
得PaaS的解决方案得以广泛应用。

Cloud Computing离我们越来越近了。在到达引爆点之前，工程师们得准备好啊。