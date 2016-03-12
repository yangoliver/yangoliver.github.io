---
layout: post
title: Preemption Implementation
description: Linux 调度器的系列文章。本文主要介绍抢占的基本概念和 Linux 内核的相关实现。 
categories: [Chinese, Software, Hardware]
tags: [scheduler, kernel, linux, hardware]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

本文主要围绕 Linux 内核调度器 Preemption 的相关实现进行讨论。其中涉及的一般操作系统和 x86 处理器和硬件概念，可能也适用于其它操作系统。

## 1. 一些概念

TBD

## 2. User Preemption

如前所述，User Preemption 主要发生在以下两类场景，

- 系统调用，中断，异常时返回用户空间时。

  此处的代码都是和处理器架构相关的，本文都以 x86 64 位 CPU 为例。

  1. 在[系统调用返回用户空间的代码里](https://github.com/torvalds/linux/blob/v3.19/arch/x86/kernel/entry_64.S#L453)检查 `TIF_NEED_RESCHED` 标志，决定是否调用 `schedule`。
  2. 不论是外设中断还是 CPU 的 APIC 中断，都会在
  [entry_64.S 里的中断公共代码里的返回用户空间路径上](https://github.com/torvalds/linux/blob/v3.19/arch/x86/kernel/entry_64.S#L896)检查 `TIF_NEED_RESCHED` 标志，决定是否调用 `schedule`。
  3. [异常返回用户空间的代码](https://github.com/torvalds/linux/blob/v3.19/arch/x86/kernel/entry_64.S#L1433)实际上与中断返回的代码共享相同的代码，`retint_careful`。

- 任务为 `TASK_RUNNING` 状态时，直接或间接地调用 `schedule`

  Linux 内核的 Kernel Preemption 没有打开的话，除了系统调用，中断，异常返回用户空间时发生 Preemption，使用 `cond_resched` 是推荐的方式来防止内核滥用 CPU。
  由于这些代码可以在只有 User Preemption 打开的时候工作，因此本文将此类代码归类为 User Preemption。

  3.13 之前的内核版本，`cond_resched` 在内核代码主动调用它时，先检查 `TIF_NEED_RESCHED` 标志和 `preempt_count` 的 `PREEMPT_ACTIVE` 标志，然后再决定是否调用 `schedule`。
  这里检查 `PREEMPT_ACTIVE` 标志，只是为了[阻止内核使用 `cond_resched` 的代码在调度器初始化完成前执行调度](https://github.com/torvalds/linux/commit/d86ee4809d0329d4aa0d0f2c76c2295a16862799)。

  而 3.13 引入的 [per_CPU 的 preempt_count patch](https://github.com/torvalds/linux/commit/c2daa3bed53a81171cf8c1a36db798e82b91afe8)，
  则将 `TIF_NEED_RESCHED` 标志设置到 preempt_count 里保存，以便一条指令就可以完成原来的两个条件判断。因此，`TIF_NEED_RESCHED` 标志检查的代码变成了只检查 `preempt_count`。
  需要注意的是，虽然 `preempt_count` 已经包含 `TIF_NEED_RESCHED` 标志，但原有的 task_struct::state 的`TIF_NEED_RESCHED` 标志仍旧在 User Preemption 代码里发挥作用。

  这里不再分析 `yield` 的实现。但需要注意的是，内核中的循环代码应该尽量使用 `cond_resched` 来让出 CPU，而不是使用 `yield`。
  [详见 `yield` 的注释](https://github.com/torvalds/linux/blob/v3.19/kernel/sched/core.c#L4287)。

## 3. Kernel Preemption

内核抢占需要打开特定的 Kconfig (CONFIG_PREEMPT=y)。Tick Preemption 和 Wakeup Preemption 的主要实现都在具体调度类算法里，这里不做详细介绍。
本文只介绍引起 Kernel Preemption 的关键代码。如前所述，Kernel Preemption 主要发生在以下两类场景，

- 中断和异常时返回用户空间时。

  如前面章节介绍，系统调用返回不会发生 Kernel Preemption，但中断和异常则会。
  [中断和异常返回内核空间的代码](https://github.com/torvalds/linux/blob/v3.19/arch/x86/kernel/entry_64.S#L929)是共享同一段实现，
  调用 `preempt_schedule_irq` 来检查 `TIF_NEED_RESCHED` 标志，决定是否调用 `schedule`。

- 禁止抢占上下文结束时。

  内核代码调用 `preempt_enable`，`preempt_check_resched` 和 `preempt_schedule` 退出禁止抢占的临界区。下面主要针对这部分实现做详细介绍。

### 3.1 preempt_count

TBD

### 3.2 preempt_disable 和 preempt_enable

在内核中需要禁止抢占的临界区代码，直接使用 preempt_disable 和 preempt_enable 即可达到目的。
关于为何以及如何禁止抢占，请参考 [Proper Locking Under a Preemptible Kernel](https://github.com/torvalds/linux/blob/v3.19/Documentation/preempt-locking.txt) 这篇文档。

如 [Preemption Overview](http://oliveryang.net/2016/03/linux-scheduler-1/) 所述，preempt_disable 和 preempt_enable 函数也被嵌入到很多内核函数的实现里，例如各种锁的进入和退出函数。

以 [preempt_enable](https://github.com/torvalds/linux/blob/v3.19/include/linux/preempt.h#L53) 的代码为例，如果 preempt_count 为 0，则调用 `__preempt_schedule`，
而该函数会最终调用 `preempt_schedule` 来尝试内核抢占。

	#define preempt_enable() \
	do { \
		barrier(); \
		if (unlikely(preempt_count_dec_and_test())) \
			__preempt_schedule(); \  /* 最终会调用 preempt_schedule */
	} while (0)

### 3.3 preempt_schedule

在 `preempt_schedule` 函数内部，在调用 `schedule` 之前，做如下检查，

1. 检查 `preempt_count` 是否非零和 IRQ 是否处于 disabled 状态，如果是则不允许抢占。

  做这个检查是为防止抢占的嵌套调用。例如，[`preempt_enable` 可以在关中断时被调用](https://github.com/torvalds/linux/commit/beed33a816204cb402c69266475b6a60a2433ceb)。
  总之，内核并不保证调用 `preempt_enable` 之前，总是可以被抢占的。这是因为，`preempt_enable` 嵌入在很多内核函数里，可以被嵌套间接调用。
  此外，抢占正在进行时也能让这种嵌套的抢占调用不会再次触发抢占。

2. 设置 `preempt_count` 的 `PREEMPT_ACTIVE`，避免抢占发生途中，再有内核抢占。

3. 被抢占的进程再次返回调度点时，检查 `TIF_NEED_RESCHED` 标志，如果有新的内核 Preemption 申请，则再次触发 Kernel Preemption。

   这一步骤是循环条件，直到当前 CPU 的 Run Queue 里再也没有申请 Preemption 的任务。

Linux v3.19 `preempt_schedule` 的代码如下，

	/*
	 * this is the entry point to schedule() from in-kernel preemption
	 * off of preempt_enable. Kernel preemptions off return from interrupt
	 * occur there and call schedule directly.
	 */
	asmlinkage __visible void __sched notrace preempt_schedule(void)
	{
		/*
		 * If there is a non-zero preempt_count or interrupts are disabled,
		 * we do not want to preempt the current task. Just return..
		 */
		if (likely(!preemptible())) /* preempt_enable 可能在被关抢占和关中断后被嵌套调用 */
			return;

		do {
			__preempt_count_add(PREEMPT_ACTIVE);
			__schedule();	/* 调用 schedule 时，PREEMPT_ACTIVE 被设置 */
			__preempt_count_sub(PREEMPT_ACTIVE);

			/*
			 * Check again in case we missed a preemption opportunity
			 * between schedule and now.
			 */
			barrier();
		} while (need_resched());	/* 恢复执行时，检查 TIF_NEED_RESCHED 标志是否设置 */
	}

## 4. schedule 函数

User 或 Kernel Preemption 的代码同样是显示地调用 schedule 函数，但与主动上下文切换中很大的不同是，调用 schedule 函数时，当前上下文任务的状态还是 **TASK_RUNNING**。

只要调用 schedule 时当前任务是 TASK_RUNNING，这时 schedule 的代码就把这次上下文切换算作强制上下文切换。下面是 schedule 代码在 Linux 3.19 的实现，

	static void __sched __schedule(void)
	{
		struct task_struct *prev, *next;
		unsigned long *switch_count;
		struct rq *rq;
		int cpu;

		[...snipped...]

		raw_spin_lock_irq(&rq->lock);

		switch_count = &prev->nivcsw; /* 默认 switch_count 是强制上下文切换的 */
		if (prev->state && !(preempt_count() & PREEMPT_ACTIVE)) {

			[...snipped...]

			switch_count = &prev->nvcsw; /* 如果 pre->state 不是 TASK_RUNNING，
			                             swtich_count 则指向主动上下文切换计数器 */
		}

		[...snipped...]

		next = pick_next_task(rq, prev);

		[...snipped...]

		if (likely(prev != next)) {
			rq->nr_switches++;
			rq->curr = next;
			++*switch_count; /* 此时确实发生了调度，要给 nivcsw 或者 nvcsw 计数器累加 */

			rq = context_switch(rq, prev, next); /* unlocks the rq */
			cpu = cpu_of(rq);
		} else
			raw_spin_unlock_irq(&rq->lock);

TBD

### 5. 关联阅读

* [Intel Intel 64 and IA-32 Architectures Software Developer's Manual Volume 3](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html) 6.14 和 13.4 章节
* [x86 系统调用入门](http://blog.csdn.net/yayong/article/details/416477)
* [Proper Locking Under a Preemptible Kernel](https://github.com/torvalds/linux/blob/v3.19/Documentation/preempt-locking.txt)
