---
layout: post
title: Linux Printk Flooding
description: A small write-up for Linux printk flooding issue
categories: [Chinese, Software]
tags: [kernel, linux]
---

> 转载时请包含作者网站链接：<http://oliveryang.net>

Linux 内核里，`printk` 是程序员们常用的错误报告和调试手段之一。然而，过度使用 `printk` 在内核里却会引发 printk flooding 这样的问题。

尤其当系统的 console 被设置为串口设备时，printk flooding 常常会导致系统进入没有响应的状态。这是因为在 `printk` 的实现里，中断会被关掉，而且还会拿自旋锁。
若打印的消息较多，`printk` 会在关中断的情况下反复循环打印日志缓冲区的内容，这就最终让 CPU 始终忙于打印而无法调度其它任务，包括 touch softlockup watchdog 的内核线程。

最终，系统因为 printk flooding 导致的没有响应。在使能了 softlockup watchdog 的系统上，会触发这个 watchdog 的超时和 panic。

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
