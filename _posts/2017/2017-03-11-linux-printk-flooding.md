---
layout: post
title: Linux Printk Flooding
description: A small write-up for Linux printk flooding issue
categories: [Chinese, Software]
tags: [kernel, linux]
---

> 转载时请包含作者网站链接：<http://oliveryang.net>

## 1. 什么是 printk flooding？

Linux 内核里，`printk` 是程序员们常用的错误报告和调试手段之一。然而，不恰当使用或者滥用 `printk` 会导致高频 printk 调用，最终在内核里引发 printk flooding 这样的问题。

在 `printk` 的实现里，中断会被关掉，而且还会拿自旋锁。如果内核需要打印的消息太多，`printk` 会在关中断的情况下反复循环打印日志缓冲区的内容，这就最终让 CPU 始终忙于打印而无法调度其它任务，
包括 touch softlockup watchdog 的内核线程。
尤其当系统的 console 被设置为串口设备时，printk flooding 会更容易发生，因为串口实在是太慢了，这会导致 `printk` 循环超时的概率大大增加。

最终，系统会因为 printk flooding 导致的没有响应。在使能了 softlockup watchdog 的系统上，会触发这个 watchdog 的超时和 panic。

## 2. 解决方法

由于 `printk` 要被设计成可以工作在任何内核的上下文，拿自旋锁和关中断似乎无法避免。

在 printk flooding 导致的 softlockup 超时中，假若引发 printk 的错误本来对系统就是致命的，那么这个问题最多影响了人们定位真正的错误根源。
但若引发 printk 的错误原本不是致命错误，那么 printk flooding 就破坏了系统的稳定性和可用性。

虽然 printk flooding 是个经典的老问题了，但我们没有快速的解决办法。
一般来说我们可以在下面几个方向上缓解和解决这个问题，

1. 提高串口速率，缓解问题。

   由于 printk 最终将调用底层注册的 console 驱动将消息打印到 console 设备上。当串口作为 console 设备时，默认为 9600 波特率的慢速串口设备将成为一大瓶颈。
   这加剧了问题的发生。为了缓解问题，我们可以将串口速率从 9600 设置到更高的波特率，例如 119200。这可以让 printk 执行的更有效率。

2. 用于 debug 性质的 printk，不要在产品模式下使用。

   内核和驱动开发者经常会定义一些打印语句帮助调试和维护代码。在产品发布前，需要注意清理这些不必要的打印语句。比如，使用条件编译开关。
   一些对维护产品非常有意义的调试打印，也可以利用内核全局的变量开关控制，默认关闭这些打印语句，需要时再动态打开。

3. 非致命错误或者消息，使用 `printk_ratelimited` 替换一般 `printk`。

   致命错误先引发 printk flooding 问题不大。凡是非致命错误引发的 printk flooding，可以用 `printk_ratelimited` 来限流。打印频率超过每 5 秒 10 个消息，多余的消息会被丢掉。
   关于 `printk_ratelimited` 的使用，可以参考内核源码中的例子。其中 [`printk_ratelimit` 和 `printk_ratelimit_burst`](https://github.com/torvalds/linux/blob/master/Documentation/sysctl/kernel.txt#L740)
   可以控制打印的时间间隔和消息个数。

## 3. 其它坑

由于 `printk` 的语义和设计目标是让它工作在所有内核上下文，因此从它诞生起就问题连连。

### 3.1 重入

即 `printk` 的调用栈里又调用了 `printk`。

### 3.1.1 异常引发重入

`printk` 到一半突然系统因触发异常 crash，就会引发重入。为了让这个重入可以正常工作，需要调用 `zap_locks` 来把函数里用到的锁都复位，避免死锁发生。

`printk` 的代码逻辑是想要阻止 crash 以外的重入的，因此有了 `recursion_bug` 这种断言 bug 的逻辑。下例来自 3.10.

    1516     /*
    1517      * Ouch, printk recursed into itself!
    1518      */
    1519     if (unlikely(logbuf_cpu == this_cpu)) {
    1520         /*
    1521          * If a crash is occurring during printk() on this CPU,
    1522          * then try to get the crash message out but make sure
    1523          * we can't deadlock. Otherwise just return to avoid the
    1524          * recursion and return - but flag the recursion so that
    1525          * it can be printed at the next appropriate moment:
    1526          */
    1527         if (!oops_in_progress && !lockdep_recursing(current)) {
    1528             recursion_bug = 1;
    1529             goto out_restore_irqs;
    1530         }
    1531         zap_locks();
    1532     }
    1533 
    1534     lockdep_off();
    1535     raw_spin_lock(&logbuf_lock);
    1536     logbuf_cpu = this_cpu;
    1537 
    1538     if (recursion_bug) {
    1539         static const char recursion_msg[] =
    1540             "BUG: recent printk recursion!";

### 3.1.2 NMI 引发重入

尽管 `printk` 一开始就关中断，但 NMI 还是不可屏蔽的。因此 NMI 上下文如果调用 `printk`，而碰巧之前的 `printk` 还在拿锁状态，重入引起的死锁就发生了。

因此，很长一段时间内，Linux 内核是不能安全地在 NMI 上下文使用 printk 的。为此，也有很多人提交了 [patch](https://lkml.org/lkml/2014/5/9/118)，并且引发了[讨论](https://lkml.org/lkml/2014/6/10/388)。

然而，去年的一个 [printk/nmi: generic solution for safe printk in NMI](https://github.com/torvalds/linux/commit/42a0bb3f71383b457a7db362f1c69e7afb96732b) 终于解决了问题。
从此，NMI 中断处理函数在进入前，都会调用 `printk_nmi_enter` 来标识这个特殊上下文，从而使 NMI 再次调用的 `printk` 进入到特殊的无锁化的实现里。

### 3.1.3 Scheduler 引发重入

除了异常，NMI，printk 自身因为用到了锁的接口，这些接口引发调度器代码被调用时，可能会再次调用 `printk`，从而导致重入。

由于有 NMI 的方案，因此这一次就是复制了 NMI 的处理方式：[printk: introduce per-cpu safe_print seq buffer](https://github.com/torvalds/linux/commit/099f1c84c0052ec1b27f1c3942eed5830d86bdbb)。
这样，在 `printk` 用到的锁代码里，都调用 `printk_safe_enter_irqsave` 这样的调用，通过标示这个特殊上下文，来对重入做无锁化处理。

### 3.2 Touch watchdog

由于 `printk` 在大多数正常内核上下文中还是需要拿自旋锁并关中断，在 `printk` 中加入引发循环或者其它显著延时的代码都需要防止内核产生 hardlockup（NMI) 和 sotflockup watchdog 超时。
因此，在任何可能引发超时的循环代码，插入 `touch_nmi_watchdog` 是可以解决一些问题的。然而，即使 watchdog 没有了超时问题，CPU 还是可能因为只能运行打印函数而无法调度其它任务。
总之，printk flooding 问题不能通过 `touch_nmi_watchdog` 来解决。
