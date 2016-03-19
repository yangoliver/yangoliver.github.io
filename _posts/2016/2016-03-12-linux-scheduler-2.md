---
layout: post
title: Preemption Implementation
description: Linux 调度器的系列文章。本文主要介绍抢占的基本概念和 Linux 内核的相关实现。 
categories: [Chinese, Software, Hardware]
tags: [scheduler, kernel, linux, hardware]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

本文主要围绕 Linux 内核调度器 Preemption 的相关实现进行讨论。其中涉及的一般操作系统和 x86 处理器和硬件概念，可能也适用于其它操作系统。

## 1. Scheduler Overview

Linux 调度器的实现实际上主要做了两部分事情，

1. 任务上下文切换

   在 [Preemption Overview](http://oliveryang.net/2016/03/linux-scheduler-1/) 里，我们对任务上下文切换做了简单介绍。
   可以看到，任务上下文切换有两个层次的实现：**公共层**和**处理器架构相关层**。任务运行状态的切换的实现最终与处理器架构密切关联。因此 Linux 做了很好的抽象。
   在不同的处理器架构上，处理器架构相关的代码和公共层的代码相互配合共同实现了任务上下文切换的功能。这也使得任务上下文切换代码可以很容易的移植到不同的处理器架构上。

2. 任务调度策略

   同样的，为了满足不同类型应用场景的调度需求，Linux 调度器也做了模块化处理。调度策略的代码也可被定义两层 **Scheduler Core (调度核心)** 和 **Scheduling Class (调度类)**。
   调度核心的代码实现了调度器任务调度的基本操作，所有具体的调度策略都被封装在具体调度类的实现中。这样，Linux 内核的调度策略就支持了模块化的扩展能力。
   Linux v3.19 支持以下调度类和调度策略，

   * Real Time (实时)调度类 - 支持 SCHED_FIFO 和 SCHED_RR 调度策略。
   * CFS (完全公平)调度类 - 支持 SCHED_OTHER(SCHED_NORMAL)，SCHED_BATCH 和 SCHED_IDLE 调度策略。(注：SCHED_IDLE 是一种调度策略，与 CPU IDLE 进程无关)。
   * Deadline (最后期限)调度类 - 支持 SCHED_DEADLINE 调度策略。

   Linux 调度策略设置的系统调用 [SCHED_SETATTR(2)](http://man7.org/linux/man-pages/man2/sched_setattr.2.html) 的手册有对内核支持的各种调度策略的详细说明。
   内核的调度类和 `sched_setattr` 支持的调度策略命名上不一致但是存在对应关系，而且调度策略的命名更一般化。这样做的一个好处是，同一种调度策略未来可能有不同的内核调度算法来实现。
   新的调度算法必然引入新的调度类。内核引入新调度类的时候，使用这个系统调用的应用不需要去为之修改。调度策略本身也是 POSIX 结构规范的一部分。
   上述调度策略中，SCHED_DEADLINE 是 Linux 独有的，POSIX 规范中并无此调度策略。[SCHED(7)](http://man7.org/linux/man-pages/man7/sched.7.html) 对 Linux 调度 API 和历史发展提供了概览，值得参考。

### 1.1 Scheduler Core

调度器核心代码位于 kernel/sched/core.c 文件。主要包含了以下实现，

* 调度器的初始化，调度域初始化。
* 核心调度函数 `__schedule` 及上下文切换的通用层代码。
* 时钟周期处理的通用层代码，包含 Tick Preemption 的代码。
* 唤醒函数，Per-CPU Run Queue 操作的代码，包含 Wakeup Preemption 通用层的代码。
* 基于高精度定时器中断实现的高精度调度，处理器间调度中断。
* 处理器 IDLE 线程，调度负载均衡，迁移任务的代码。
* 与调度器有关的系统调用的实现代码。

调度器核心代码的主要作用就是调度器的模块化实现，降低了跨处理器平台移植和实现新调度算法模块的重复代码和模块间的耦合度，提高了内核可移植性和可扩展性。

### 1.2 Scheduling Class

在 Linux 内核引入一种新调度算法，基本上就是实现一个新的 Scheduling Class (调度类)。调度类需要实现的所有借口定义在 `struct sched_class` 里。
下面对其中最重要的一些调度类接口做简单的介绍，

* enqueue_task

  将待运行的任务插入到 Per-CPU Run Queue。典型的场景就是内核里的唤醒函数，将被唤醒的任务插入 Run Queue 然后设置任务运行态为 `TASK_RUNNING`。

  对 CFS 调度器来说，则是将任务插入红黑树，给 `nr_running` 增加计数。

* dequeue_task

  将非运行态任务移除出 Per-CPU Run Queue。典型的场景就是任务调度引起阻塞的内核函数，把任务运行态设置成 `TASK_INTERRUPTIBLE` 或 `TASK_UNINTERRUPTIBLE`，然后调用 `schedule` 函数，最终触发本操作。

  对 CFS 调度器来说，则是将不在处于运行态的任务从红黑树中移除，给 `nr_running` 减少计数。

* yield_task

  处于运行态的任务申请主动让出 CPU。典型的场景就是处于运行态的应用调用 [`sched_yield(2)`](http://man7.org/linux/man-pages/man2/sched_yield.2.html) 系统调用，直接让出 CPU。
  此时系统调用 `sched_yield` 系统调用先调用 `yield_task` 申请让出 CPU，然后调用 `schedule` 去做上下文切换。

  对 CFS 调度器来说，如果 `nr_running` 是 1，则直接返回，最终 `schedule` 函数也不产生上下文切换。否则，任务被标记为 skip 状态。调度器在红黑树上选择待运行任务时肯定会跳过该任务。
  之后，因为 `schedule`  函数被调用，`pick_next_task` 最终会被调用。其代码会从红黑树中最左侧选择一个任务，然后把要放弃运行的任务放回红黑树，然后调用上下文切换函数做任务上下文切换。

* check_preempt_curr

  用于在待运行任务插入 Run Queue 后，检查是否应该 Preempt 正在 CPU 运行的当前任务。Wakeup Preemption 的实现逻辑主要在这里。

  对 CFS 调度器而言，主要是在是否能满足调度时延和是否能保证足够任务运行时间之间来取舍。CFS 调度器也提供了预定义的 Threshold 允许做 Wakeup Preemption 的调优。

* pick_next_task

  选择下一个最适合调度的任务，将其从 Run Queue 移除。并且如果前一个任务还保持在运行态，即没有从 Run Queue 移除，则将当前的任务重新放回到 Run Queue。内核 `schedule` 函数利用它来完成调度时任务的选择。

  对 CFS 调度器而言，大多数情况下，下一个调度任务是从红黑树的最左侧节点选择并移除。
  如果前一个任务是其它调度类，则调用该调度类的 `put_prev_task` 方法将前一个任务做正确的安置处理。
  但如果前一个任务如果也属于 CFS 调度类的话，为了效率，跳过调度类标准方法 `put_prev_task`，但核心逻辑仍旧是 `put_prev_task_fair` 的主要部分。
  关于 `put_prev_task` 的具体功能，请参考随后的说明。

* put_prev_task

  将前一个正在 CPU 上运行的任务做拿下 CPU 的处理。如果任务还在运行态则将任务放回 Run Queue，否则，根据调度类要求做简单处理。此函数通常是 `pick_next_task` 的密切关联操作，是 `schedule` 实现的关键部分。

  如果前一个任务属于 CFS 调度类，则使用 CFS 调度类的具体实现 `put_prev_task_fair`。此时，如果任务还是 `TASK_RUNNING` 状态，则被重新插入到红黑树的最右侧。
  如果这个任务不是 `TASK_RUNNING` 状态，则已经从红黑树移除过了，只需要修改 CFS 当前任务指针 `cfs_rq->curr` 即可。

* set_curr_task

  当任务改变自己的调度类或者任务组时，该函数被调用。用户进程可以使用 [`sched_setscheduler`](http://man7.org/linux/man-pages/man2/sched_setscheduler.2.html)
  系统调用，通过设置自己新的调度策略来修改自己的调度类。

  对 CFS 调度器而言，当任务把自己调度类从其它类型修改成 CFS 调度类，此时需要把该任务设置成正当前 CPU 正在运行的任务。例如把任务从红黑树上移除，设置 CFS 当前任务指针 `cfs_rq->curr` 和调度统计数据等。

* task_tick

  这个函数通常在系统周期性 (Per-tick) 的时钟中断上下文调用，判断是否当前运行任务需要 Preemption 来被强制剥夺运行。Tick Preemption 的实现逻辑主要在这里。

  对 CFS 调度器而言，主要是在是否能满足调度时延和是否能保证足够任务运行时间之间来取舍。CFS 调度器也提供了预定义的 Threshold 允许做 Tick Preemption 的调优。

Linux 内核的 CFS 调度算法就是通过实现该调度类结构来实现其主要逻辑的，CFS 的代码主要集中在 sched/fair.c 源文件。
下面的 `sched_class` 结构初始化代码包含了本节介绍的所有方法在 CFS 调度器实现中的入口函数名称，

	const struct sched_class fair_sched_class = {

			[...snipped...]

		.enqueue_task		= enqueue_task_fair,
		.dequeue_task		= dequeue_task_fair,
		.yield_task		= yield_task_fair,

			[...snipped...]

		.check_preempt_curr	= check_preempt_wakeup,

			[...snipped...]

		.pick_next_task		= pick_next_task_fair,
		.put_prev_task      = put_prev_task_fair,

			[...snipped...]

		.set_curr_task          = set_curr_task_fair,

			[...snipped...]

		.task_tick		= task_tick_fair,

			[...snipped...]
	};

### 1.3 preempt_count

TBD

## 2. 触发抢占

### 2.1 Tick Preemption

TBD

### 2.2 Wakeup Preemption

TBD

## 3. 执行 Preemption

### 3.1 User Preemption

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
  POSIX 规范里规定了 [`sched_yield(2)`](http://man7.org/linux/man-pages/man2/sched_yield.2.html) 调用，一些实时调度类的应用可以使用 `sched_yield` 让出 CPU。
  内核 API `yield` 使用了 `sched_yield` 的实现。与 `cond_resched` 最大的不同是，`yield` 会使用具体调度类的 `yield_task` 方法。不同调度类对 `yield_task` 可以有很大不同。
  例如，`SCHED_DEADLINE` 调度策略里，`yield_task` 方法会让任务睡眠，这时的 `sched_yield` 已经不再属于 Preemption 的范畴。

#### 3.1.1 schedule 对 User Preemption 的处理

User Preemption 的代码同样是显示地调用 schedule 函数，但与主动上下文切换中很大的不同是，调用 schedule 函数时，当前上下文任务的状态还是 **TASK_RUNNING**。
只要调用 schedule 时当前任务是 TASK_RUNNING，这时 schedule 的代码就把这次上下文切换算作强制上下文切换，并且这次上下文切换不会涉及到把被 Preempt 任务从 Run Queue 移除操作。

下面是 schedule 代码在 Linux 3.19 的实现，

	static void __sched __schedule(void)
	{
		struct task_struct *prev, *next;
		unsigned long *switch_count;
		struct rq *rq;
		int cpu;

		[...snipped...]

		raw_spin_lock_irq(&rq->lock);

		switch_count = &prev->nivcsw; /* 默认 switch_count 是强制上下文切换的 */
		if (prev->state && !(preempt_count() & PREEMPT_ACTIVE)) { /* User Preemption 是 TASK_RUNNING 且无 PREEMPT_ACTIVE 置位，所以下面代码不会执行 */
			if (unlikely(signal_pending_state(prev->state, prev))) {
				prev->state = TASK_RUNNING;	/* 可中断睡眠有 Pending 信号，只做上下文切换，无需从运行队列移除 */
			} else {
				deactivate_task(rq, prev, DEQUEUE_SLEEP); /* 不是 TASK_RUNNING 且无 PREEMPT_ACTIVE 置位，需要从运行队列移除 */
				prev->on_rq = 0;


			[...snipped...]

			switch_count = &prev->nvcsw; /* 不是 TASK_RUNNING 且无 PREEMPT_ACTIVE 置位，
			                             swtich_count 则指向主动上下文切换计数器 */
		}

		[...snipped...]

		next = pick_next_task(rq, prev);

		[...snipped...]

		if (likely(prev != next)) { /* Run Queue 上真有待调度的任务才做上下文切换 */
			rq->nr_switches++;
			rq->curr = next;
			++*switch_count; /* 此时确实发生了调度，要给 nivcsw 或者 nvcsw 计数器累加 */

			rq = context_switch(rq, prev, next); /* unlocks the rq 真正上下文切换发生 */
			cpu = cpu_of(rq);
		} else
			raw_spin_unlock_irq(&rq->lock);

从代码可以看出，User Preemption 触发的上下文切换，都被算作了**强制上下文切换**。

### 3.2 Kernel Preemption

内核抢占需要打开特定的 Kconfig (CONFIG_PREEMPT=y)。本文只介绍引起 Kernel Preemption 的关键代码。如前所述，Kernel Preemption 主要发生在以下两类场景，

- 中断和异常时返回内核空间时。

  如前面章节介绍，系统调用返回不会发生 Kernel Preemption，但中断和异常则会。
  [中断和异常返回内核空间的代码](https://github.com/torvalds/linux/blob/v3.19/arch/x86/kernel/entry_64.S#L929)是共享同一段实现，
  调用 `preempt_schedule_irq` 来检查 `TIF_NEED_RESCHED` 标志，决定是否调用 `schedule`。

- 禁止抢占上下文结束时。

  内核代码调用 `preempt_enable`，`preempt_check_resched` 和 `preempt_schedule` 退出禁止抢占的临界区。下面主要针对这部分实现做详细介绍。

如 [Preemption Overview](http://oliveryang.net/2016/03/linux-scheduler-1/) 所述，User Preemption 总是限定在任务处于 `TASK_RUNNING` 的几个有限的固定时机发生。
而 Kernel Preemption 发生时，任务的运行态是不可预料的，任务运行态可能处于任何运行状态，如 `TASK_UNINTERRUPTIBLE` 状态。

一个典型的例子就是，任务睡眠时要先将任务设置成睡眠态，然后再调用 `schedule` 来做真正的睡眠。

	set_current_state(TASK_UNINTERRUPTIBLE);
	/* 中断在 schedule 之前发生，触发 Kernel Preemption */
	schedule();

设置睡眠态和 `schedule` 调用之间并不是原子的操作，大多时候也没有禁止抢占和关中断。这时 Kernel Preemption 如果正好发生在两者之间，那么就会造成我们所说的情况。
上面的例子里，中断恰好在任务被设置成 `TASK_UNINTERRUPTIBLE` 之后发生。中断退出后，`preempt_schedule_irq` 就会触发 Kernel Preemption。

下面的例子里，Kernel Preemption 可以发生在最后一个 `spin_unlock` 退出时，这时当前任务状态是 `TASK_UNINTERRUPTIBLE`，

	prepare_to_wait(wq, &wait.wait, TASK_UNINTERRUPTIBLE);
	spin_unlock(&inode->i_lock);
	spin_unlock(&inode_hash_lock); /* preempt_enable 在 spin_unlock 内部被调用 */
	schedule();

不论是中断退出代码调用 `preempt_schedule_irq`， 还是 `preempt_enable` 调用 `preempt_schedule`，都会最在满足条件时触发 Kernel Preemption。
下面以 `preempt_enable` 调用 `preempt_schedule` 为例，剖析内核代码实现。

#### 3.2.1 preempt_disable 和 preempt_enable

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

#### 3.2.2 preempt_schedule

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
			__preempt_count_add(PREEMPT_ACTIVE); /* 调用 schedule 前，PREEMPT_ACTIVE 被设置 */
			__schedule();
			__preempt_count_sub(PREEMPT_ACTIVE); /* 结束一次抢占，PREEMPT_ACTIVE 被清除 */

			/*
			 * Check again in case we missed a preemption opportunity
			 * between schedule and now.
			 */
			barrier();
		} while (need_resched());	/* 恢复执行时，检查 TIF_NEED_RESCHED 标志是否设置 */
	}

需要注意，`schedule` 调用前，`PREEMPT_ACTIVE` 标志已经被设置好了。

#### 3.2.3 schedule 对 Kernel Preemption 的处理

如前所述，进入函数调用前，`PREEMPT_ACTIVE` 标志已经被设置。根据当前的任务的运行状态，我们分别做出如下分析，

1. 当前任务是 `TASK_RUNNING`。

   任务不会被从其所属 CPU 的 Run Queue 上移除。这时只发生上下文切换，当前任务被下一个任务取代后在 CPU 上运行。

2. 当前任务是其它非运行态。

   继续本节开始的例子，当前任务设置好 `TASK_UNINTERRUPTIBLE` 状态，即将调用 `schedule` 之前被 `spin_unlock` 里的 `preempt_enable` 调用 `preempt_schedule`。

   由于是 Kernel Preemption 上下文，`PREEMPT_ACTIVE` 被设置，任务不会被从 CPU 所属 Run Queue 移除而睡眠，这时只发生上下文切换，当前任务被下一个任务取代在 CPU 上运行。
   当 Run Queue 中已经处于 `TASK_UNINTERRUPTIBLE` 状态的任务被调度到 CPU 上时，`PREEMPT_ACTIVE` 标志早被清除，因此，该任务会被 `deactivate_task` 从 Run Queue 上删除，进入到睡眠状态。

   这样的处理保证了 Kernel Preemption 的正确性，以及后续被 Preempt 任务再度被调度时的正确性，

   * Preemption 的本质是一种打断引起的上下文切换，不应该处理任务的睡眠操作。

     当前被 Preempt 的任务从 Run Queue 移除去睡眠的工作，本来就应该由任务自己代码调用的 `schedule` 来完成。
     假如没有 `PREEMPT_ACTIVE` 标志的检查，那么当前被 Preempt 任务就在 `preempt_schedule` 调用 `schedule` 时提前被从 Run Queue 移除而睡眠。
     这样一来，该任务原来代码的语义发生了变化，从任务角度看，Preemption 只是一种任务打断，被 Preempt 任务的睡眠不应该由 `preempt_schedule` 的代码来做。

   * Run Queue 队列移除操作给 Kernel Preemption 的代码路径被增加了不必要的时延。

     不但如此，这个被 Preempt 任务再次被唤醒后，该任务还未执行的 `schedule` 调用还会被执行一次。

下面是 `schedule` 的代码，针对 Kernel Preemption 做了详细注释，

	static void __sched __schedule(void)
	{
		struct task_struct *prev, *next;
		unsigned long *switch_count;
		struct rq *rq;
		int cpu;

		[...snipped...]

		raw_spin_lock_irq(&rq->lock);

		switch_count = &prev->nivcsw; /* Kernel Preemption 使用强制上下文切换计数器 */
		if (prev->state && !(preempt_count() & PREEMPT_ACTIVE)) { /* 非 TASK_RUNNING 和非 Kernel Preemption 任务才从运行队列移除 */
			if (unlikely(signal_pending_state(prev->state, prev))) {
				prev->state = TASK_RUNNING;	/* 可中断睡眠有 Pending 信号，只做上下文切换，无需从运行队列移除 */
			} else {
				deactivate_task(rq, prev, DEQUEUE_SLEEP); /* 非 TASK_RUNNING，非 Kernel Preemption，需要从运行队列移除 */
				prev->on_rq = 0;


			[...snipped...]

				switch_count = &prev->nvcsw; /* 非 TASK_RUNNING 和非 Kernel Preemption 任务使用这个计数器 */
			}
		}

### 4. 关联阅读

* [Preemption Overview](http://oliveryang.net/2016/03/linux-scheduler-1/)
* [Intel Intel 64 and IA-32 Architectures Software Developer's Manual Volume 3](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html) 6.14 和 13.4 章节
* [x86 系统调用入门](http://blog.csdn.net/yayong/article/details/416477)
* [Linux Kernel Stack](https://github.com/torvalds/linux/blob/v3.19/Documentation/x86/x86_64/kernel-stacks)
* [Proper Locking Under a Preemptible Kernel](https://github.com/torvalds/linux/blob/v3.19/Documentation/preempt-locking.txt)
* [Modular Scheduler Core and Completely Fair Scheduler](http://lwn.net/Articles/230501/)
* [Deadline scheduling for Linux](http://lwn.net/Articles/356576/)
