---
layout: post
title: Linux CPI FlameGraph
description: Using CPI FlameGraph for Linux performance
categories: [Chinese, Software, Hardware]
tags: [perf, trace, kernel, linux, memory, hardware]
---

>本文首发于[内核月谈微信号](https://mp.weixin.qq.com/s/k5Iz2yE5iYrbuD3Gjf2NEg)，由杨勇, 吴一昊共同完成;
>转载时请包含原文或者作者网站链接：<http://oliveryang.net>

* content
{:toc}

## 1. 什么是 CPI ？##

本小节讲述为什么使用 CPI 分析程序性能的意义。如果已经非常了解 CPI 对分析程序性能的意义，可以跳过本小节的阅读。

### 1.1 程序怎么样才能跑得快 ？###

理解什么是 CPI，首先让我们思考一个问题：在一个给定的处理器上，如何才能让程序跑得更快呢？

假设程序跑得快慢的标准是程序的执行时间，那么程序执行的快慢，就可以用如下公式来表示：

       程序执行时间 = 程序总指令数 x 每 CPU 时钟周期时间 x 每指令执行所需平均时钟周期数

因此，要想程序跑得快，即减少**程序执行时间**，我们就需要在以下三个方面下功夫：

1. 减少**程序总指令数**

   要减少程序执行的总指令数，可能有以下手段：
    - 算法优化；好的算法设计，可能带来更少的指令执行数
    - 更高效的编译器或者解释器；新的编译器或者解释器，可能对同样的源代码，生成更少的机器码。
    - 用更底层的语言优化；这是为何 Linux 内核代码使用 C 语言，并且还喜欢内联汇编。
    - 更新的处理器指令；新的处理器指令，对处理某类特殊目的运算更有帮助，而新版本编译器最重要的工作就是，在新的处理器上，用最新的高效指令；例如，x86 SSE，AVX 指令。
2. 减少**每 CPU 时钟周期时间**

   这一点很容易理解，缩短 CPU 时钟周期的时间，实际上就是要提高 CPU 的主频。这正是 Intel 过去战无不胜的法宝之一。今天，由于主频的提高已经到了制造工艺的极限，CPU 时钟周期的时间很难再继续降低了。

3. 减少**每指令执行所需平均时钟周期数**

   如何减少每指令执行所需平均 CPU 时钟周期数呢？让我们先从 CPU 设计角度看一下：
    - 标量处理器 (Scalar Processor) ；一个 CPU 时钟周期只能执行一条指令；
    - 超标量处理器 (Superscalar Processor)；一个 CPU 时钟周期可以执行多条指令；通常这个是靠在处理器里实现多级流水线 (Pipeline) 来实现的。

   因此不难看出，如果使用支持超标量处理器的 CPU，利用 CPU 流水线提高指令并行度，那么就可以达到我们的目的了。流水线的并行度越高，执行效率越高，那么**每指令执行所需平均时钟周期数**就会越低。

   当然，流水线的并行度和效率，又取决于很多因素，例如，取指令速度，访存速度，指令乱序执行 (Out-Of-Order Execution)，分支预测执行 (Branch Prediction Execution)，投机执行 (Speculative Execution）的能力。一旦流水线并行执行的能力降低，那么程序的性能就会受到影响。关于超标量处理器，流水线，乱序执行，投机执行的细节，这里不再一一赘述，请查阅相关资料。

   另外，在 SMP，或者多核处理器系统里，程序还可以通过并行编程来提高指令的并行度，因此，这也是为什么今天在 CPU 主频再难以提高的情况下，CPU 架构转为 Multi-Core 和 Many-Core。

由于提高 CPU 主频的同时，又要保障一个 CPU 时钟周期可以执行更多的指令，因此处理器厂商需要不断地提高制造工艺，降低 CPU 的芯片面积和功耗。

### 1.2 CPI 和 IPC ###

在计算机体系结构领域，经常可以看到 CPI 的使用。CPI 即 Cycle Per Instruction 的缩写，它的含义就是**每指令周期数**。此外，在一些场合，也可以经常看到 IPC，即 Instruction Per Cycle，含义为**每周期指令数**。

因此不难得出，CPI 和 IPC 的关系为，

       CPI = 1 / IPC

使用 CPI 这个定义，本文开篇用于衡量程序执行性能的公式，**如果具体到单 CPU 的程序执行性能场景**，实际上可以表示为：

       Execution Time (T) = Instruction Count x Time Per Cycle X CPI

由于受到硅材料和制造工艺的限制，处理器主频的提高已经面临瓶颈，因此，程序性能的提高，主要的变量在 Instruction Count 和 CPI 这两个方面。

在 Linux 上，通过 `perf` 工具，通过 Intel 处理器提供的寄存器 (PMU)，可以很容易测量一个程序的 IPC。例如，下例就可以给出 Java 程序的 IPC，8 秒多的时间里，这个 Java 程序的 IPC 是 0.54：

```
$sudo perf stat -p `pidof java`
^C
 Performance counter stats for process id '3191':

          1.616171      task-clock (msec)         #    0.000 CPUs utilized
               221      context-switches          #    0.137 M/sec
                 0      cpu-migrations            #    0.000 K/sec
                 2      page-faults               #    0.001 M/sec
         2,907,189      cycles                    #    1.799 GHz
         2,083,821      stalled-cycles-frontend   #   71.68% frontend cycles idle
         1,714,355      stalled-cycles-backend    #   58.97% backend  cycles idle
         1,561,667      instructions              #    0.54  insns per cycle
                                                  #    1.33  stalled cycles per insn
           286,102      branches                  #  177.025 M/sec
     <not counted>      branch-misses              (0.00%)

       8.841569895 seconds time elapsed
```

那么，通过 IPC，我们也可以换算出 CPI 是 `1/0.54`，约为 1.85.

通常情况下，通过 CPI 的取值，我们可以大致判断一个计算密集型任务，到底是 CPU 密集型的还是 Memory 密集型的：

- CPI 小于 1，程序通常是 CPU 密集型的；
- CPI 大于 1，程序通常是 Memory 密集型的;

### 1.3 重新认识 CPU 利用率 ###

对程序员来说，判断一个计算密集型任务运行效率的重要依据就是看程序运行时的 CPU 利用率。很多人认为 CPU 利用率高就是程序的代码在疯狂运行。实际上，CPU 利用率高，也有可能是 CPU 正在**忙等**一些资源，如访问内存遇到了瓶颈。

一些计算密集型任务，在正常情况下，CPI 很低，性能原本很好。CPU 利用率很高。但是随着系统负载的增加，其它任务对系统资源的争抢，导致这些计算任务的 CPI 大幅上升，性能下降。而此时，很可能 CPU 利用率上看，还是很高的，但是这种 CPU 利用率的高，实际上体现的是 CPU 的忙等，及流水线的停顿带来的效应。

Brendan Gregg 曾在 [CPU Utilization is Wrong](http://www.brendangregg.com/blog/2017-05-09/cpu-utilization-is-wrong.html) 这篇博客中指出，CPU 利用率指标需要结合 CPI/IPC 指标一起来分析。并详细介绍了前因后果。感兴趣的读者可以自行阅读原文，或者订阅**内核月谈**公众号，阅读我们公众号[非常靠谱的译文](https://mp.weixin.qq.com/s/KaDJ1EF5Y-ndjRv2iUO3cA)。

至此，相信读者已经清楚，在不修改二进制程序的前提下，通过 CPI 指标了解程序的运行性能，有着非常重要的意义。对于计算密集型的程序，只通过 CPU 利用率这样的传统指标，也无法帮助你确认你的程序的运行效率，必须将 CPU 利用率和 CPI/IPC 结合起来看，确定程序的执行效率。

### 1.4 如何分析 CPI/IPC 指标异常？###

虽然利用 `perf` 可以很方便获取 CPI/IPC 指标，但是想分析和优化程序高 CPI 的问题，就需要一些工具和分析方法，将 CPI 高的原因，以及与之关联的软件的调用栈找到，从而决定优化方向。

关于 CPI 高的原因分析，在 Intel 64 and IA-32 Architectures Optimization Reference Manual, 附录 B 里有介绍。其中主要的思路就是按照自顶向下的方法，自顶向下排查， 4 种引起 CPI 变高的主要原因，

<img src="/media/images/2018/cpi-top-down-method.png" width="100%" height="100%" />

由于本文主要是介绍 CPI 火焰图，对于本小节的自顶向下的分析方法，限于篇幅所限，就不详细展开了，我们稍后会有专门的文章做详细介绍。

## 2. CPI 火焰图 ##

Brendan Gregg 在 [CPI Flame Graphs: Catching Your CPUs Napping](http://www.brendangregg.com/blog/2014-10-31/cpi-flame-graphs.html) 一文中，介绍了使用 CPI 火焰图来建立 CPI 和软件调用栈的关联。

我们已经知道，光看 CPU 利用率并不能知道 CPU 在干嘛。因为 CPU 可能执行到一条指令就停下来，等待资源了。这种等待对软件是透明的，因此从用户角度看，CPU 还是在被使用状态，但是实际上，指令并没有有效地执行，CPU 在忙等，这种 CPU 利用率并不是有效的利用率。

要发现 CPU 在 busy 的时候实际上在干什么，最简单的方法就是测量平均 CPI。CPI 高说明运行每条指令用了更多的周期。这些多出来的周期里面，通常是由于流水线的停顿周期 (Stalled Cycles) 造成的，例如，等待内存读写。

而 CPI 火焰图，可以基于 CPU 火焰图，提供一个可视化的基于 CPU 利用率和 CPI 指标，综合分析程序 CPU 执行效率的方案。

下面这个 CPI 火焰图引用自 Brendan Gregg 博客文章。可以看到，CPI 火焰图是基于 CPU 火焰图，根据 CPI 的大小，在每个条加上了颜色。红色代表指令，蓝色代表流水线的停顿：

<img src="http://www.brendangregg.com/blog/images/2014/cpi-freebsd-kernel.svg" width="100%" height="100%" />

火焰图中，每个函数帧的宽度，显示了函数或其子函数在 CPU 上的次数，和普通 CPU 火焰图完全一样。而颜色则显示了函数在 CPU 上是运行 (running 红色) 还是停顿 (stalled 蓝色)。

火焰图里，颜色范围，从最高CPI为蓝色（执行最慢的指令），到最低CPI为红色 (执行最快的指令)。火焰图是 SVG 格式，矢量图，因此支持鼠标点击缩放。

然而，Brendan Gregg 博客中的这篇博客，CPI 火焰图是基于 FreeBSD 操作系统特有的命令生成的，而在 Linux 上，应该怎么办呢？

## 3. 一个小程序 ##

让我们写一个人造的小程序，展示在 Linux 下 CPI 火焰图的使用。

这是一个最简的小程序，其中包含如下两个函数：

1. `cpu_bound`
    函数主体是 nop 指令的循环；由于 nop 指令是不访问内存的最简指令之一，
    因此该函数 CPI 一定小于 1，属于典型的 CPU 密集型的代码。
2. `memory_bound`
    函数使用 `_mm_clflush` 驱逐缓存，人为触发程序的 L1 D-Cache Load Miss。
    因此该函数 CPI 必然大于 1，属于典型的 Memory 密集型的代码。

下面是程序的源码：

```
	 #include <stdlib.h>
	 #include <emmintrin.h>
	 #include <stdio.h>
	 #include <signal.h>

	 char a = 1;

	 void memory_bound() {
	         register unsigned i=0;
	         register char b;

	         for (i=0;i<(1u<<24);i++) {
	                 // evict cacheline containing a
 	                 _mm_clflush(&a);
 	                 b = a;
	         }
	 }
	 void cpu_bound() {
	         register unsigned i=0;
	         for (i=0;i<(1u<<31);i++) {
	                 __asm__ ("nop\nnop\nnop");
	         }
	 }
	 int main() {
	         memory_bound();
	         cpu_bound();
	         return 0;
	 }
```

在上述小程序运行时，我们使用如下命令，编译运行程序，并生成 CPI 火焰图，

```
$ gcc cpu_and_mem_bound.c -o cpu_and_mem_bound -gdwarf-2 -fno-omit-frame-pointer -O0

$ perf record \
    -e cpu/event=0xa2,umask=0x1,name=resource_stalls_any,period=2000003/ \
    -e cpu/event=0x3c,umask=0x0,name=cpu_clk_unhalted_thread_p,period=2000003/\
    --call-graph dwarf -F 200 ./cpu_and_mem_bound
$ perf script > out.perf

$ FlameGraph/stackcollapse-perf.pl --event-filter=cpu_clk_unhalted_thread_p \
    out.perf > out.folded.cycles
$ FlameGraph/stackcollapse-perf.pl --event-filter=resource_stalls_any \
    out.perf > out.folded.stalls
$ FlameGraph/difffolded.pl -n out.folded.stalls out.folded.cycles | \
    FlameGraph/flamegraph.pl --title "CPI Flame Graph: blue=stalls, red=instructions" \
  --width=900 > cpi_flamegraph_small.svg
```

最后生成的火焰图如下，

<img src="/media/images/2018/cpi-flame-graph-micro-benchmark.svg" width="100%" height="100%" />

可以看到，CPI 火焰图看到的结果，是符合我们的预期的：
- 该程序所有的 CPU 时间，都分布在  `cpu_bound` 和 `memory_bound` 两个函数里
- 同是 CPU 占用时间，但 `cpu_bound` 是红色的，代表这个函数的指令在 CPU 上一直持续运行
- 而 `memory_bound` 是蓝色的，代表这个函数发生了严重的访问内存的延迟，导致了流水线停顿，属于忙等

## 4. 一个benchmark ##

现在，我们可以使用 CPI 火焰图来分析一个略真实一些的测试场景。下面的 CPI 火焰图，来自 `fio` 的测试场景。

<img src="/media/images/2018/cpi-flame-graph-fio-1.svg" width="100%" height="100%" />

这个 `fio` 对 SATA 磁盘，做多进程同步 Direct IO 顺序写，可以看到：
- 红颜色为标记为 CPU Bound 的函数。其中颜色最深的是 `_raw_spin_lock`，这是自旋锁的等待循环引起的。
- 蓝颜色为标记为 Memory Bound 的函数。其中颜色最深的是 `fio` 测试程序的函数 `get_io_u`，如果使用 `perf` 程序进一步分析，这个函数里发生了严重的 LLC Cache Miss。

因为 CPI 火焰图是矢量图，支持缩放，所以以上结论可以通过放大 `get_io_u` 的调用栈进一步确认，

<img src="/media/images/2018/cpi-flame-graph-fio-2.png" width="100%" height="100%" />

到这里，读者会发现，使用 CPI 火焰图，可以很方便地做 CPU 利用率的分析，找到和定位引发 CPU 停顿的函数。一旦找到相关的函数，就可以通过 `perf annotate` 命令对引起停顿的指令作出进一步确认。并且，我们可以利用 `1.4` 小节的自顶向下分析方法，对 CPU 哪个环节产生瓶颈作出判断。最后，结合这些信息，决定优化方向。

## 5. 小结 ##

本文介绍了使用 CPI 火焰图分析程序性能的方法。CPI 火焰图不但展示了程序的 Call Stack 与 CPU 占用率的关联性，而且还揭示了这些 CPU 占用率里，哪些部分是真正的有效的运行时间，哪些部分实际上是 CPU 因某些停顿造成的忙等。

系统管理员可以通过此工具发现系统存在的资源瓶颈，并且通过一些系统管理命令来缓解资源的瓶颈；例如，应用间的 Cache 颠簸干扰，可以通过将应用绑到不同的 CPU 上解决。

而应用开发者则可以通过优化相关函数，来提高程序的性能。例如，通过优化代码减少 Cache Miss，从而降低应用的 CPI 来减少处理器因访存停顿造成的性能问题。

## 6. 参考资料 ##
* [CPU Utilization is Wrong](http://www.brendangregg.com/blog/2017-05-09/cpu-utilization-is-wrong.html)
* [Flame Graphs](http://www.brendangregg.com/flamegraphs.html)
* [CPI Flame Graphs: Catching Your CPUs Napping](http://www.brendangregg.com/blog/2014-10-31/cpi-flame-graphs.html)
