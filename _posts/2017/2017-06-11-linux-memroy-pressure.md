---
layout: post
title: Linux Memory Pressure - 1
description: About system memory pressure, which includes hardware and linux kernel knowledge
categories: [Chinese, Software, Hardware]
tags: [perf, memory, kernel, linux, hardware]
---

> 草稿状态，请勿装载。转载时请包含作者网站链接：<http://oliveryang.net>

* content
{:toc}

## 1. 内存压力的定义 ##

当系统内存的分配，访问，释放因资源竞争而导致了恶化，进而影响到了应用软件的性能指标，我们就称系统处于内存压力之下。

这里面强调了以下几点：
- 内存资源使用的三个方面：分配，访问，释放。

  三个方面中，内存访问是关键，内存的分配和释放通常会影响到内存的访问性能。
  由于大多数现代操作系统都实现了虚拟内存管理，并采用了 Demand Paging 的设计，因此影响到应用性能指标的物理内存的分配和释放，经常发生在该虚拟地址首次被访问时。
  例如，访问内存引起 page fault，这时引发了物理页的分配。若物理页不足，则又引发页回收，导致脏页或者匿名页写入磁盘，然后页面释放后被回收分配。
- 内存资源竞争：可以是硬件层面和软件层面的竞争。

  由于现代处理器的设计，访问内存硬件资源的竞争可以发生在各个层面，下面以 x86 为例：
  - Hyper thread 引起流水线 frontend 和 bandend 的竞争，引发访存停滞 (Stall)。
  - 多级 TLB 和 paging sructure cache，因进程上下文切换或者内存映射改变而失效 (TLB flush)，或因 TLB miss 而引发延迟。
  - 多级 Cache，因 Cache miss 而引发延迟。
  - NUMA 架构, 因 CPU 本地访存 (iMC) 或者远程访存 (QPI) 而引发内存访问延迟上的差异。同样地，设备 DMA 也有本地和远程访存延迟差异。

  软件层面的竞争就更多了，由于 Linux 内核虚拟内存的设计，可能发生如下领域的竞争：
  - Page fault
  - 页分配
  - 页回收
  - 用户内存和内核内存管理的开销：如元数据状态更新和锁竞争。
- 应用可感知：内存资源竞争而引起其性能指标的变化，从用户角度可感知才有意义。

  一个应用的端到端的操作，可以转化成为成百上千次访存操作。当一个端到端操作可以量化到 N 次访存操作时，访存的性能指标的差异变得可以估算起来。

## 2. 内存性能指标 ##

下面将从三个维度去考量内存的性能指标。从应用的角度看，它们对应用的端到端性能可能会造成一定的影响。

### 2.1 Throughput ###

内存访问吞吐量。

例如，Intel Broadwell 某个系统的硬件内存带宽上限为 130GB/s。那么我们可以利用 `perf -e intel_cqm` 命令观查当前的应用的内存使用的吞吐量，看是否达到了系统硬件的带宽瓶颈。
详情请参考关联文档中的 [Introduction to Cache Quality of service in Linux Kernel](http://events.linuxfoundation.org/sites/events/files/slides/presentlinuxcon.pdf) 这篇文档。

### 2.2 IOPS ###

内存访问的 IOPS。

### 2.3 Latency ###

内存访问的延迟。

## 3. 影响内存性能的因素 ##

TBD。

## 4. 关联文档 ##

* [Introduction to Cache Quality of service in Linux Kernel](http://events.linuxfoundation.org/sites/events/files/slides/presentlinuxcon.pdf)
