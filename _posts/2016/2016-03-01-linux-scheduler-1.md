---
layout: post
title: Preemption Overview
description: Linux 调度器的系列文章。本文主要介绍抢占的基本概念和 Linux 内核的相关实现。 
categories: [Chinese, Software, Hardware]
tags: [scheduler, kernel, linux, hardware]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

本文主要围绕 Linux 内核调度器 Preemption 的相关实现进行讨论。其中涉及的一般操作系统和 x86 处理器和硬件概念，可能也适用于其它操作系统。

## 1. 背景知识

要深入理解 Preemption 必须对操作系统的 Context Switch 做一个全面的梳理。最终可以了解 Preemption 和 Context Switch 概念上的区别与联系。

### 1.1 Context Switch

**Context Switch (上下文切换)** 指任何操作系统上下文保存和恢复执行状态，以便于被安全地打断和稍后被正确地恢复执行。
一般操作系统中通常因以下三种方式引起上下文切换，

- Task Scheduling (任务调度)

  任务调度一般是由调度器代码在内核空间完成的。
  通常需要将当前 CPU 执行任务的代码，用户或内核栈，地址空间切换到**下一个要运行任务的代码**，**用户或内核栈**，**地址空间**。

- Interrupt (中断) 或 Exception (异常)

  中断和异常是由硬件产生但由软件来响应和处理的。
  这个过程中，涉及到将用户态或内核态代码切换至**中断处理代码**。同时可能还涉及到用户进程栈或内核栈切换到**中断栈**。
  支持保护模式的处理器可能还涉及到保护模式的切换。x86 处理器是通过 Interrupt Gate (中断门) 完成的。

- System Call (系统调用)

  系统调用是由用户态代码主动调用，使用户进程陷入到内核态调用内核定义的各种系统调用服务。
  这个过程中，涉及到将任务的用户态代码和栈在同一任务上下文上切换至**内核系统调用代码**和同一任务的**内核栈**。

### 1.2 Preemption

**Preemption (抢占)** 是指操作系统允许满足某些重要条件(例如：优先级，公平性)的任务打断当前正在 CPU 上运行的任务而得到调度执行。
并且这种打断不需要当前正在运行的任务的配合，同时被打断的程序可以在后来可以再次被调度恢复执行。

多任务操作系统可以按照 Cooperative Multitasking (协作多任务) 和 Preemptive Multitasking (抢占式多任务) 来划分。
本质上，抢占就是允许高优先级的任务可以立即打断低优先级的任务而得到运行。对低 Scheduling Latency (调度延迟) 或者 Real Time (实时) 操作系统的需求来说，支持完全抢占的特性是必须的。

三种上下文切换方式中，系统调用始终发生在同一任务的上下文中，只有**中断异常**和**任务调度**机制才涉及到一个任务被令一个上下文打断。
Preemption 最终需要借助任务调度来完成任务的打断。但是，任务调度却和这三种上下文切换方式都密切相关，要理解 Preemption，必须对三种机制有深入的了解。

## 2. 任务调度

任务的调度需要内核代码通过调用调度器核心的 `schedule` 函数引起。它主要完成以下工作，

- 完成任务调度所需的 Context Switch (上下文切换)
- 调度算法相关实现：选择下一个要运行的任务，任务运行状态和 Run Queue (运行队列) 的维护等

本文主要关注上下文切换和引起任务调度的原因。

### 2.1 任务调度上下文切换

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

一般来说，任务调度，或者说任务上下文切换，可以分为以下两大方式来进行，

- Voluntary Context Switch (主动上下文切换)
- Involuntary Context Switch (强制上下文切换)

### 2.2 主动上下文切换

主动上下文切换就是任务主动通过直接或者间接调用 schedule 函数引起的上下文切换。引起主动上下文切换的常见时机有，

1. 任务因为等待 IO 操作完成或者其它资源而阻塞。

   任务显式地调用 schedule 前，把任务运行态设置成 `TASK_UNINTERRUPTIBLE`。保证任务阻塞后不能因信号到来而引起睡眠过程的中断，从而被唤醒。
   Linux 内核各种同步互斥原语，如 Mutex，Semaphore，wait_queue，R/W Semaphore，及其他各种引起阻塞的内核函数。

2. 等待资源和特定事件的发生而主动睡眠。

   任务显式地调用 schedule 前，把任务运行态被设为 `TASK_INTERRUPTIBLE`。保证即使等待条件不满足也可以被任务接收到的信号所唤醒，重新进入运行态。
   Linux 内核各种同步互斥原语，如 Mutex，Semaphore，wait_queue，及其它各种引起睡眠的内核函数。

3. 特殊目的，例如 debug 和 trace。

   任务在显式地用 schedule 函数前，利用 set_current_state 将任务设置成**非 TASK_RUNNING 状态**。
   例如，设置成 TASK_STOPPED 状态，然后调用 schedule 函数。

### 2.3 强制上下文切换

强制上下文切换是指并非任务自身意愿调用 schedule 函数而引发的上下文切换。从定义可以看出，强制上下文切换的主要原因都和 Preemption 有关。

#### 2.3.1 触发 Preemption

##### 2.3.1.1 Tick Preemption

在周期性的时钟中断里，内核调度器检查当前正在运行任务的持续运行时间是否超出具体调度算法支持的时间上限，从而决定是否剥夺当前任务的运行。
一旦决定剥夺在 CPU 上任务的运行，则会给正在 CPU 上运行的当前任务设置一个**请求重新调度的标志**：`TIF_NEED_RESCHED`。

需要注意的是，TIF_NEED_RESCHED 标志置位后，并没有立即调用 schedule 函数发生上下文切换。真正的上下文切换动作是 User Preemption 或 Kernel Preemption 的代码完成的。

User Preemption 或 Kernel Preemption 在很多代码路径上放置了检查当前任务的 `TIF_NEED_RESCHED` 标志，并显式调用 schedule 的逻辑。
接下来很快就会有机会调用 schedule 来触发任务切换，这时抢占就真正的完成了。上下文切换发生时，下一个被调度的任务将由具体调度器算法来决定从运行队列里挑选。

例如，如果时钟中断刚好打断正在用户空间运行的进程，那么当 Tick Preemption 的代码将当前被打断的用户进程的 `TIF_NEED_RESCHED` 标志置位。随后，时钟中断处理完成，并返回用户空间。
此时，User Preemption 的代码会在中断返回用户空间时检查 `TIF_NEED_RESCHED` 标志，如果置位就会调用 schedule 来完成上下文切换。

##### 2.3.1.2 Wakeup Preemption

当原因需要唤醒另一个进程时，`try_to_wake_up` 的内核函数将会帮助被唤醒的进程选择一个 CPU 的 Run Queue，然后把进程插入到 Run Queue 里，并设置成 `TASK_RUNNING` 状态。
这个过程中 CPU Run Queue 的选择和 Run Queue 插入操作都是调用具体的调度算法回调函数来实现的。

任务插入到 Run Queue 后，调度器立即将新唤醒的任务和正在 CPU 上执行的任务交给具体的调度算法去比较，决定是否剥夺当前任务的运行。
与 Tick Preemption 一样，一旦决定剥夺在 CPU 上执行的任务的运行，则会给当前任务设置一个 `TIF_NEED_RESCHED` 标志。而实际的 schedule 调用并不是在这时完成的。
但 Wakeup Preemption 在此处真正特殊的地方在于，执行唤醒操作的任务可能把被唤醒的任务插入到**本地 CPU** 的 Run Queue，但还可能插入到**远程 CPU** 的 Run Queue。
因此，`try_to_wake_up` 函数的调用根据被唤醒的任务将插入 Run Queue 所属的 CPU 和执行唤醒任务正在运行的 CPU 关系，分为如下两种情况，

* 共享缓存

  被唤醒任务的目标 CPU 和当前运行唤醒 CPU 共享缓存。

  唤醒函数在返回过程中，只要当前任务运行到任何一处 User Preemption 或 Kernel Preemption 的代码，这些代码就会检查到 `TIF_NEED_RESCHED` 标志，并调用 schedule 的位置，上下文切换才真正发生。
  实际上，如果 Kernel Preemption 是打开的，在唤醒操作结束时的 `spin_unlock` 或者随后的各种可能的中断退出路径都有 Kernel Preemption 调用 schedule 的时机。

* 不共享缓存

  被唤醒任务的目标 CPU 和当前运行唤醒 CPU 不共享缓存。

  这种情况下，唤醒操作在设置 `TIF_NEED_RESCHED` 标志之后，会立即向被唤醒任务 Run Queue 所属的 CPU 发送一个 IPI (处理器间中断)，然后才返回。
  以 Intel x86 架构为例，那个远程 CPU 的 `RESCHEDULE_VECTOR` 被初始化来响应这个中断，最终中断处理函数 `scheduler_ipi` 在远程 CPU 上执行。
  早期 Linux 内核，`scheduler_ipi` 其实是个空函数，因为所有中断返回用户空间或者内核空间都的出口位置都已经有 User Preemption 和 Kernel Preemption 的代码在那里，所以 schedule 一定会被调用。
  后来的 Linux 内核里，又利用 `scheduler_ipi` 让远程 CPU 来做远程唤醒的主要操作，从而减少 Run Queue 锁竞争。所以现在的 `scheduler_ipi` 加入了新的代码。

因 Wakeup Preemption 而导致的上下文切换发生时，下一个被调度的任务将由具体调度器算法来决定从运行队列里挑选。
对于刚唤醒的任务，如果成功触发了 Wakeup Preemption，则某些具体的调度算法会给它一个优先被调度的机会。

#### 2.3.2 执行 Preemption

#### 2.3.2.1 User Preemption

User Preemption 发生在如下两种典型的状况，

* 系统调用，中断及异常在**返回用户空间**前，检查 CPU 当前正在运行的任务的 `TIF_NEED_RESCHED` 标志，如果置位则直接调用 schedule 函数。

* 任务为 `TASK_RUNNING` 状态时，直接或间接地调用 `schedule`

  举个间接调用的例子：内核态的代码在循环体内调用 cond_resched()，yield() 等内核 API，给其它任务得到调度的机会，防止独占滥用 CPU。

  在内核态写逻辑上造成长时间循环的代码，有可能造成内核死锁或者造成超长调度延迟，尤其是当 Kernel Preemption 没有打开时。
  这时可以在循环体内调用 cond_resched() 内核 API，有条件的让出 CPU。这里说的有条件是因为 cond_resched 要检查 `TIF_NEED_RESCHED` 标志，看是否有新的 Preemption 的请求。
  而 `yield` 内核 API，不检查 `TIF_NEED_RESCHED` 标志，则无条件触发任务切换，但在所在 CPU Run Queue 没有其它任务的情况下，不会发生真正的任务切换。

#### 2.3.2.2 Kernel Preemption

早期 Linux 内核只支持 User Preemption。2.6内核 Kernel Preemption 支持被引入。

Kernel Preemption 发生在以下几种情况，

* 中断，异常结束处理后，返回到内核空间时。

  以 x86 为例，Linux 在中断和异常处理代码的公共代码部分(即从具体 handler 代码退出后)，判断是否返回内核空间，然后调用 `preempt_schedule_irq` 检查 `TIF_NEED_RESCHED` 标志，触发任务切换。

* 禁止内核抢占处理结束时

  作为完全抢占内核，Linux 只允许在当前内核上下文需要禁止抢占的时候才使用 `preempt_disable` 禁止抢占，内核代码在禁止抢占后，应该尽早调用 `preempt_enable` 使能抢占，避免引入高调度延迟。
  为尽快处理在禁止抢占期间 pending 的重新调度申请，内核在 `preempt_enable` 里会调用 `preempt_schedule` 检查 `TIF_NEED_RESCHED` 标志，触发任务切换。

  使用 `preempt_disable` 和 `preempt_enable` 的内核上下文有很多，典型而又为人熟知的有各种内核锁的实现，如 Spin Lock，Mutex，Semaphore，R/W Semaphore，RCU 等。

与 User Preemption 不同的是，上述两种 Kernel Preemption 的情况发生时，任务的运行态可能已经被设置成 `TASK_RUNNING` 以外的睡眠状态，如 `TASK_UNINTERRUPTIBLE`。
此时接下来的内核 `__schedule` 代码会有特殊处理，检查 `PREEMPT_ACTIVE` 对上一个被 Preempt 的任务跳过移除队列操作，保证 Kernel Preemption 尽快被处理。
而 User Preemption 则不会在当前任务在 `TASK_RUNNING` 以外的状态下发生，这是因为 User Preemption 总是发生在当前任务处于 `TASK_RUNNING` 的特殊位置。

## 3. 中断和异常

**Interrupt (中断)** 通常是由硬件或者是特殊软件指令触发的处理器需要立即响应的信号。**Exception (异常)** 广义上被归类为中断的一种。
但狭义上，中断和异常最大的区别是，中断发生和处理是异步的，但异常的发生和处理是同步的。

**System Call** 因为利用了特殊软件指令给处理器产生了同步的 **Trap (陷阱)**，也可被归类为异常的一种。但由于其设计和用途和异常处理有明显区别，将在另一个章节做单独介绍。
本节主要介绍中断和异常。

### 3.1 中断和异常的上下文切换

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

### 3.2 中断引起的任务调度

Linux 内核里，中断和异常因其打断的上下文不同，在返回时可能会触发以下类型的任务调度，

- User Preemption

  中断和异常打断了用户态运行的任务，在返回时检查 `TIF_NEED_RESCHED` 标志，决定是否调用 `schedule`。

- Kernel Preemption

  中断和异常打断了内核态运行的任务，在返回时调用 `preempt_schedule_irq`。其代码会检查 `TIF_NEED_RESCHED` 标志，决定是否调用 `schedule`。

User 和 Kernel Preemption 的代码是实现在 Linux 内核所有中断和异常处理函数通用处理代码层的，因此，中断异常的具体处理函数返回后就会被执行。
尽管所有类型中断都可能引发任务切换，和任务调度和抢占密切相关，但以下两种中断直接与调度器相关，是内核调度器设计的一部分，

- Timer Interrupt (时钟中断)
- Scheduler IPI (调度器处理器间中断)

#### 3.2.1 时钟中断

**Timer Interrupt (时钟中断)** 对操作系统调度有着特殊的意义。
如前所述，周期性执行的时钟中断处理函数会触发 Tick Preemption 的请求。随后中断在返回前，根据返回的上下文不同，可能会执行到 User Preemption 和 Kernel Preemption 的逻辑。
这里的中断，可以是操作系统任何的中断，例如一般外设的中断。
由于操作系统一般在具体中断处理函数进入前和退出后有公共中断处理逻辑，所以 Preemption 一般都实现在这里，而具体的中断处理函数并无 Preemption 的 Knowledge。
而我们知道，外设中断一般具有随机性，所以，如果没有时钟中断的存在，那么 Preemption 的实现恐怕很难有时间保证了。因此，周期性的时钟中断在这里发挥了重要的作用。
当然，除了 Preemption，时钟中断还担负了系统中很多重要的功能的处理，例如调度队列的均衡，进程时间的更新，软件定时器的执行等。
下面从 Preemption 的角度简单的讨论一下与时钟中断的关系，

- 时钟中断源

  内核的时钟中断是基于其运行硬件支持的可以周期触发时钟中断的设备来实现的。因此在不同硬件平台上，其实现机制和差异比较大。
  早期的 Linux x86 支持 PIT 还有 HPET 做时钟中断中断源。现在 Linux 默认使用 x86 处理器的 Local APIC Timer 做时钟中断源。
  Local APIC Timer 与 PIT 和 HPET 最大的不同就是，APIC timer 中断是 Per-CPU 的，但 PIT 和 HPET 是系统全局的。因此每 CPU 的 APIC Timer 中断更加适合 SMP 系统的 Preemption 实现。

- 时钟中断频率

  早期 Linux 和一些 Unix 服务操作系统内核将时钟中断频率设置成 100HZ。这意味着时钟中断的执行周期是 10ms。而新 Linux 内核默认将 x86 上 Linux 内核的频率提高到 1000HZ。
  这样，在 x86 上，时钟中断的处理周期缩短为 1ms。一个时钟中断周期通常被称作一个 **Tick**。
  通常，Unix/Linux 都会使用一个全局技术器来对系统启动以来的时钟中断次数来计数。Linux 内核中的这个全局变量被叫做 **Jiffies**。因此 Linux 内核中一个 Tick 也被叫一个 Jiffy。

  当一个 Tick 从 10ms 缩短到 1ms，系统因处理高频时钟中断的开销理论上会增大，但着也带来的更快更低延迟的 Preemption。由于硬件性能的提高，这种改变的负面影响很有限，但好处是很明显的。

#### 3.2.2 调度器处理器间中断

**Scheduler IPI (调度器处理器间中断)** 最初的引入主要是为了解决 SMP 系统中，唤醒代码触发 Wakeup Preemption 时，需要远程 CPU 协助产生 User Preemption 或 Kernel Preemption 而引入的机制。
其具体的过程如下，

1. 唤醒代码经过具体调度器算法为被唤醒任务选择 CPU。
2. 当选择的 CPU 是远程的时，将处于睡眠的进程唤醒并放入到远程 CPU 所属的 Run Queue
3. 唤醒代码调用具体调度算法检查是否触发 Wakeup Preemption，并在返回前触发 Scheduler IPI (调度器处理器间中断)。
4. 远程 CPU 正在执行的代码被打断，Scheduler IPI 处理函数被执行。
5. Scheduler IPI 处理函数内部并无针对 Preemption 的实际处理。
6. Scheduler IPI 处理函数退出时会进入中断处理的公共代码部分，根据中断返回上下文是用户还是内核上下文，触发 User Preemption 或 Kernel Preemption。

需要指出的是，新的 x86 平台和 Linux 内核里，Timer Interrupt 和 Scheduler IPI 都属于 CPU Local APIC 处理的中断。
在 Linux 内核里，在 entry_64.S 里的公共入口和返回都由 `apicinterrupt` 处理。
而 `apicinterrupt` 和其它外设中断的公共入口返回代码共享 User Preemption 或 Kernel Preemption 的处理逻辑，即 `ret_from_intr` 的处理。

## 4. 系统调用

**System Call (系统调用)** 是为应用程序请求操作系统内核服务而设计的，一整套相对稳定的编程接口和服务例程。本小节主要关注系统调用的上下文切换和引起的任务调度部分。

### 4.1 系统调用的上下文切换

系统调用与中断和异常最大的不同是，系统调用的发生是同步的，是应用程序通过编程接口主动触发的，因此不存在打断当前执行任务的作用。
所以系统调用自身就是正在执行任务的一部分，只不过，它是为任务在内核空间执行代码而已。
因此，当任务调用系统调用主动陷入到内核执行系统调用代码时，必然发生上下文切换，一般来说，这个上下文切换是由硬件来辅助完成的。

以 Intel x86 处理器为例，系统调用完成的用户空间到内核空间的上下文切换是由叫做 Trap Gate (陷阱门) 的硬件机制来实现的。Linux 操作系统支持以下两种方式触发 Intel x86 的陷阱门，

- int 0x80 指令，较老的不支持系统调用指令的处理器使用。
- sysenter 快速系统调用指令，较新的处理器支持。

陷阱门与中断使用的中断门类似，但其门调用发生过程中，没有像中断门一样禁止中断。当用户态的代码通过 glibc 的代码发出上述指令触发系统调用时，其上下文切换按照如下步骤发生，

1. 当前任务的代码 `CS:RIP` 指向了陷阱门为系统调用向量早已初始化好的系统调用公共入口函数
2. CPU 陷阱门存自动保存用户任务的上下文，例如，系统调用号，用户空间的代码 `CS:RIP` 和用户栈 `SS:RSP` 等。具体 layout 请参考硬件手册。
3. 系统调用公共入口代码保存其它寄存器上下文，最后将 `SS:RSP` 指向了该任务内核栈 `struct thread_info` 的地址，完成了任务用户栈到内核栈的切换。
4. 系统调用公共入口代码做必要检查后，调用全局的系统调用表，进入到具体系统调用的服务例程。

### 4.2 系统调用引起的任务调度

与中断处理类似，具体系统调用函数退出后，公共系统调用代码返回用户空间时，可能会触发 User Preemption，即检查 `TIF_NEED_RESCHED` 标志，决定是否调用 `schedule`。
系统调用不会触发 Kernel Preemption，因为系统调用返回时，总是返回到用户空间，这一点与中断和异常有很大的不同。

### 5. 调度触发时机总结

Linux 内核源码 `schedule` 的注释写的非常精炼，所以就不啰嗦了，直接上源码，

	/*
	 * __schedule() is the main scheduler function.
	 *
	 * The main means of driving the scheduler and thus entering this function are:
	 *
	 *   1. Explicit blocking: mutex, semaphore, waitqueue, etc.
	 *
	 *   2. TIF_NEED_RESCHED flag is checked on interrupt and userspace return
	 *      paths. For example, see arch/x86/entry_64.S.
	 *
	 *      To drive preemption between tasks, the scheduler sets the flag in timer
	 *      interrupt handler scheduler_tick().
	 *
	 *   3. Wakeups don't really cause entry into schedule(). They add a
	 *      task to the run-queue and that's it.
	 *
	 *      Now, if the new task added to the run-queue preempts the current
	 *      task, then the wakeup sets TIF_NEED_RESCHED and schedule() gets
	 *      called on the nearest possible occasion:
	 *
	 *       - If the kernel is preemptible (CONFIG_PREEMPT=y):
	 *
	 *         - in syscall or exception context, at the next outmost
	 *           preempt_enable(). (this might be as soon as the wake_up()'s
	 *           spin_unlock()!)
	 *
	 *         - in IRQ context, return from interrupt-handler to
	 *           preemptible context
	 *
	 *       - If the kernel is not preemptible (CONFIG_PREEMPT is not set)
	 *         then at the next:
	 *
	 *          - cond_resched() call
	 *          - explicit schedule() call
	 *          - return from syscall or exception to user-space
	 *          - return from interrupt-handler to user-space
	 */

### 6. 关联阅读

本文主要介绍了解 Preemption 所需的基本概念，以及 Linux 内核是如何实现 User Preemption 和 Kernel Preemption 的。由于 Context Switch 与 Preemption 密切相关，所以也结合 Intel x86 处理器做了详细分析。
这些内容在很多 Linux 内核书籍也都有覆盖，但要深入理解，还是需要结合某种处理器架构相关的知识来一起学习，否则很难深入理解。因此了解些硬件相关的知识是必要的。

* [Intel Intel 64 and IA-32 Architectures Software Developer's Manual Volume 3](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html) 6.14 和 13.4 章节
* [x86 系统调用入门](http://blog.csdn.net/yayong/article/details/416477)
* [Proper Locking Under a Preemptible Kernel](https://github.com/torvalds/linux/blob/v3.19/Documentation/preempt-locking.txt)
* [Linux Kernel Stack](https://github.com/torvalds/linux/blob/v3.19/Documentation/x86/x86_64/kernel-stacks)
