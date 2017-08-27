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

内存访问吞吐量。通常计量方式为 BPS，即每秒的字节数。

例如，Intel Broadwell 某个系统的硬件内存带宽上限为 130GB/s。那么我们可以利用 `perf -e intel_cqm` 命令观查当前的应用的内存使用的吞吐量，看是否达到了系统硬件的带宽瓶颈。
详情请参考关联文档中的 [Introduction to Cache Quality of service in Linux Kernel](http://events.linuxfoundation.org/sites/events/files/slides/presentlinuxcon.pdf) 这篇文档。

TBD.

### 2.2 IOPS ###

内存访问每秒操作次数。通常计量方式为 IOPS。对内存来说，IO 操作分为 Load 和 Store，IOPS 即每秒的 Load/Store 次数。

由于现代处理器存在非常复杂的 Memory Cache Hierarchy 的设计，因此，软件发起的一条引起内存 Read 访存指令，可能引起 Cache Evition 操作，进而触发内存的 Store 操作。
而一条引起内存 Write 访存指令，可能也会引起 Cache Miss 操作，进而引发内存的 Load 操作。
因此，要观察系统的内存 IOPS 指标，只能借助 CPU 的 PMU 机制。

例如，Intel 的 PMU 支持 PEBS 机制，可以利用 `perf mem` 命令来观察当前应用的内存访问的 IOPS。

TBD.

### 2.3 Latency ###

内存访问的延迟。通常计量单位为时间。

内存访问延迟的时间单位，从纳秒 (ns), 微妙 (us), 毫秒 (ms)，甚至秒 (s) 不等，这取决于硬件和软件上的很多因素：
- 当内存访问命中 cache 时，访存延迟通常是 ns 级别的。
- 若内存访问引起操作系统的 page fault，访存延迟对应用来说就推迟到了 us ，甚至百 us 级别。
- 若内存访问时的 page fault 遭遇了物理内存紧张，引发了操作系统的页回收，访存延迟可以推迟到 ms 级，一些极端情况可以是百 ms 级，直至 s 级。

因此，观察内存访问延迟并没有通用的，很方便的工具。软件层面的访存延迟，可以利用 OS 的动态跟踪工具。例如 page fult 的延迟，可以利用 ftrace 和 perf 之类的工具观测。

## 3. 影响内存访问性能的因素 ##

很多因素可以影响到系统内存的性能，

- 资源总数量的竞争

- 软件并发访问竞争

- 总线并发访问竞争

- 内存的局部性问题

TBD。

## 4. 关联文档 ##

* [Introduction to Cache Quality of service in Linux Kernel](http://events.linuxfoundation.org/sites/events/files/slides/presentlinuxcon.pdf)
