---
layout: post
title: Linux Scheduler - 1
description: Linux 调度器的系列文章。本文主要介绍抢占的基本概念和 Linux 内核的相关实现。 
categories:
- [Chinese, Software]
tags:
- [scheduler, kernel, linux]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

## Preemption (抢占)

本文主要围绕 Linux 内核调度器 Preemption 的相关实现进行讨论。其中涉及的一般操作系统和 x86 处理器和硬件概念，可能也适用于其它操作系统。

### 1. 背景知识

#### 1.1 Preemption

**Preemption (抢占)** 是指操作系统允许满足某些重要条件(例如：优先级，公平性)的任务打断当前正在 CPU 上运行的任务而得到调度执行。
并且这种打断不需要当前正在运行的任务的配合，同时被打断的程序可以在后来可以再次被调度恢复执行。

在操作系统里，打断正在执行的任务有两种常见的机制，

- Interrupt (中断)或 Exception (异常) 处理
- Task Scheduling (任务调度)

Preemption 最终需要借助任务调度来完成任务的打断。但任务调度却和中断，异常机制密切相关。

#### 1.2 Preemption 的主要原因

TBD

#### 1.3 Preemption 发生的时机

TBD

##### 1.3.1 User Preemption

##### 1.3.2 Kernel Preemption

### 2. 中断和异常

#### 2.1 中断和异常的上下文切换

很多英文技术文档和讨论里把这种类型的打断动作叫做 Pin，意思就是当前的任务没有被切换走，而是被 Pin 住不能动弹了。
这种打断不像 Context Switch 那样，涉及到地址空间的切换。而且这种打断通畅和处理器和外围硬件的中断机制有关。
依赖于不同操作系统的实现，可能中断或者异常处理程序有自己的独立内核栈，例如当前 Linux 版本在32位和64位 x86 上的实现；
也可能使用任务当前的内核栈，例如早期 Linux 在32位 x86 上的实现。

以 Intel 的 x64 处理器为例，当外设产生中断后，CPU 通过 Interrupt Gate (中断门) 打断了当前任务的执行。
此时，不论正在执行的任务处于用户态还是内核态，中断门都会无条件保存当前任务执行的寄存器执行上下文。
这些寄存器里就有当前任务下一条待执行的代码段指令寄存器 `CS:RIP` 和当前任务栈指针寄存器 `SS:RSP`。
而新的中断上下文的代码段指令寄存器 `CS:RIP` 的值，早由系统启动时由 x86 的 IDT (中断描述符表) 相关的初始化代码设置为所有外设中断的公共 IRQ Routine (中断处理例程) 函数。
在 Linux 3.19 的这个公共中断处理例程 entry_64.S 的 irq_entries_start 汇编函数里，
[SAVE_ARGS_IRQ](https://github.com/torvalds/linux/blob/v3.19/arch/x86/kernel/entry_64.S#L782) 宏定义会把存储在 per-CPU 变量 irq_stack_ptr 里的内核 IRQ Stack (中断栈) 赋值给 SS:RSP。
这样一来，一个完整的中断上下文切换就由 CPU 和中断处理例程共同协作完成。中断执行完毕，从中断例程的返回过程则会利用之前保存的上下文，恢复之前被打断的任务。

x64 的异常机制与中断机制类似，都利用了 IDT 来完被打断任务的 `CS:RIP` 和 `SS:RSP` 的保存，但 IDT 表里异常的公共入口函数却是不同的函数。
而且在这个函数的汇编实现里，切换到内核 IRQ Stack 的代码是借助硬件里预先被内核初始化好的 IST (中断服务表) 里保存的 `SS:RSP` 的值，这是与一般外设中断处理的不同之处。

另外，x64 和 x32 的 IDT 机制在从内核态进入到中断门时，硬件在是否把当前任务的 `SS:RSP` 寄存器压栈的处理上有明显差别。
此外，IDT 在初始化时，IDT 描述符里的 IST 选择位如果非零，则意味着内核 IRQ Stack 的切换是要由内核代码借助 IST 实现。
但如果 IDT 描述符的 IST 选择位是零，则内核的 IRQ Stack 切换由内核代码借助 per-CPU 的内核中断栈变量实现。

由于主题和篇幅限制，这里不会详细介绍中断的上下文切换机制。了解 x86 平台中断和异常的上下文切换机制，需要对 x86 处理器的硬件规范有所了解。
[Intel Intel 64 and IA-32 Architectures Software Developer's Manual Volume 3](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html)
里的 **6.14 EXCEPTION AND INTERRUPT HANDLING IN 64-BIT MODE** 章节里有硬件的详细介绍，尤其详细说明了32位和64位，以及中断和异常的详细差异。

#### 2.2 中断引起的任务调度

TBD

##### 2.2.1 时钟中断

##### 2.2.2 IPI (处理器间中断)

### 3. 任务调度

任务的调度需要内核代码通过调用调度器核心的 schedule 函数引起。它主要完成以下工作，

- 完成任务调度所需的 Context Switch (上下文切换)
- 调度算法相关实现：选择下一个要运行的任务，任务运行状态和 Run Queue (运行队列) 的维护等

本文主要关注上下文切换和引起任务调度的原因。

#### 3.1 任务调度上下文切换

内核 schedule 函数其中一个重要的处理就是 Task Context Switch (任务上下文切换)。调度器的任务上下文切换主要做两件事，

- 任务地址空间的上下文切换。

   在 Linux 上通过 [switch_mm](https://github.com/torvalds/linux/blame/v3.19/arch/x86/include/asm/mmu_context.h#L36) 函数完成。
   x86 CPU 通过装载下一个待运行的任务的页目录地址 mm-\>pgd 到 CR3 寄存器来实现。

- 任务 CPU 运行状态的上下文切换。

   主要是 CPU 各寄存器的切换，包括通用寄存器，浮点寄存器和系统寄存器的上下文切换。

   在 Linux x86 64位的实现里，指令｀CS:EIP｀ 和栈 ｀SS:ESP｀ 还有其它通用寄存器的切换由 [switch_to](https://github.com/torvalds/linux/blame/v3.19/arch/x86/include/asm/switch_to.h#L108) 完成。
   Linux 描述任务的数据结构是 `struct task_struct`，其中的 thread 成员(`struct thread_struct`)用于保存上下文切换时任务的 CPU 状态。

   由于浮点寄存器上下文切换代价比较大，而且，很多使用场景中，被调度的任务可能根本没有使用过 FPU (浮点运算单元)，所以 Linux 和很多其它 OS 都采用了 Lazy FPU 上下文切换的设计。
   但随着 Intel 今年来引入 XSAVE 特性来加速 FPU 保存和恢复，Linux 内核在 3.7 引入了[non-lazy FPU 上下文切换](https://github.com/torvalds/linux/commit/304bceda6a18ae0b0240b8aac9a6bdf8ce2d2469)。
   当内核检测到 CPU 支持 XSAVE 指令集，就使用 non-lazy 方式。这也是
   [Intel Intel 64 and IA-32 Architectures Software Developer's Manual Volume 3](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html)
   的章节 **13.4 DESIGNING OS FACILITIES FOR SAVING X87 FPU, SSE AND EXTENDED STATES ON TASK OR CONTEXT SWITCHES** 里建议的方式。

#### 3.2 任务调度的时机和方式

一般来说，任务调度，或者说任务上下文切换，可以分为以下两大方式来进行，

- Voluntary Context Switch (主动上下文切换)
- Involuntary Context Switch (强制上下文切换)

##### 3.2.1 主动上下文切换

主动上下文切换就是任务主动通过直接或者间接调用 schedule 函数引起的上下文切换。引起主动上下文切换的常见时机有，

1. 任务因为等待 IO 操作完成或者其它资源而阻塞。

   任务显式地调用 schedule 前，把任务运行态设置成 `TASK_UNINTERRUPTIBLE`。保证任务阻塞后不能因信号到来而引起睡眠过程的中断，从而被唤醒。
   Linux 内核各种同步互斥原语，如 Mutex，Semaphore，R/W Semaphore，及其他各种引起阻塞的内核函数。

2. 等待资源和特定事件的发生而主动睡眠。

   任务显式地调用 schedule 前，把任务运行态被设为 `TASK_INTERRUPTIBLE`。保证即使等待条件不满足也可以被任务接收到的信号所唤醒，重新进入运行态。
   Linux 内核各种同步互斥原语，如 Mutex，Semaphore，及其它各种引起睡眠的内核函数。

3. 特殊目的，例如 debug 和 trace。

   任务在显式地用 schedule 函数前，利用 set_current_state 将任务设置成**非 TASK_RUNNING 状态**。
   例如，设置成 TASK_STOPPED 状态，然后调用 schedule 函数。

##### 3.2.2 强制上下文切换

强制上下文切换是指并非任务自身意愿调用 schedule 函数而引发的上下文切换。

1. Tick Preemption

   在周期性的时钟中断里，内核调度器检查当前正在运行任务的持续运行时间是否超出具体调度算法支持的时间上限，从而决定是否剥夺当前任务的运行。
   一旦决定剥夺在 CPU 上任务的运行，则会给正在 CPU 上运行的当前任务设置一个**请求重新调度的标志**：`TIF_NEED_RESCHED`。

   需要注意的是，TIF_NEED_RESCHED 标志置位后，并没有立即调用 schedule 函数发生上下文切换。真正的上下文切换动作是 User Preemption 或 Kernel Preemption 的代码完成的。

   User Preemption 或 Kernel Preemption 在很多代码路径上放置了检查当前任务的 TIF_NEED_RESCHED 标志，并显式调用 schedule 的逻辑。
   接下来很快就会有机会调用 schedule 来触发任务切换，这时抢占就真正的完成了。上下文切换发生时，下一个被调度的任务将由具体调度器算法来决定从运行队列里挑选。

   例如，如果时钟中断刚好打断正在用户空间运行的进程，那么当 Tick Preemption 的代码将当前被打断的用户进程的 `TIF_NEED_RESCHED` 标志置位。随后，时钟中断处理完成，并返回用户空间。
   此时，User Preemption 的代码会在中断返回用户空间时检查 `TIF_NEED_RESCHED` 标志，如果置位就会调用 schedule 来完成上下文切换。

2. Wakeup Preemption

   任务被唤醒，变成 TASK_RUNNING 状态，插入到 Run Queue 上。此时调度器将新唤醒的任务和正在 CPU 上执行的任务交给具体的调度算法去比较，决定是否剥夺当前任务的运行。
   与 Tick Preemption 一样，一旦决定剥夺在 CPU 上执行的任务的运行，则会给当前任务设置一个 `TIF_NEED_RESCHED` 标志。实际的 schedule 调用并不是在这时完成的。

   接下来只要当前任务运行到任何一处 User Preemption 或 Kernel Preemption 的代码，这些代码就会检查到 `TIF_NEED_RESCHED` 标志，并调用 schedule 的位置，上下文切换才真正发生。

   因 Wakeup Preemption 而导致的上下文切换发生时，下一个被调度的任务将由具体调度器算法来决定从运行队列里挑选。
   对于刚唤醒的任务，如果成功触发了 Wakeup Preemption，则某些具体的调度算法会给它一个优先被调度的机会。

3. User Preemption

   User Preemption 发生在如下两种典型的状况，

   * 系统调用，中断及异常在**返回用户空间**前，检查 CPU 当前正在运行的任务的 `TIF_NEED_RESCHED` 标志，如果置位则直接调用 schedule 函数。

   * 内核态的代码在循环体内调用 cond_resched()，yield() 等内核 API，给其它任务得到调度的机会，防止独占滥用 CPU。

     在内核态写逻辑上造成长时间循环的代码，有可能造成内核死锁或者造成超长调度延迟，尤其是当 Kernel Preemption 没有打开时。
     这时可以在循环体内调用 cond_resched()，yield() 等内核 API，有条件的让出 CPU。这里说的有条件是因为 cond_resched 要检查 `TIF_NEED_RESCHED` 标志。
	 而 yield 在所在 CPU Run Queue 没有任务的情况下，也不会发生真正的任务切换。

   User Preemption 的代码同样是显示地调用 schedule 函数，与前面主动上下文切换中不同的是，调用 schedule 函数时，当前上下文任务的状态还是 **TASK_RUNNING**。
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


4. Kernel Preemption

   TBD

### 4. schedule 函数

TBD

### 5. 关联阅读

* [Intel Intel 64 and IA-32 Architectures Software Developer's Manual Volume 3](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html) 6.14 和 13.4 章节
