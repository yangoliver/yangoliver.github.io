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

## Linux 内核 Preemption 概念及其实现

本文主要围绕 Linux 内核调度器的 Preemption 实现进行讨论，但其涉及的一般概念，可能也适用于其它操作系统。

### 1. 什么是 Preemption?

**Preemption (抢占)** 是指操作系统允许满足某些重要条件(例如：优先级，公平性)的任务打断当前正在 CPU 上运行的任务而得到调度执行。
并且这种打断不需要当前正在运行的任务的配合，同时被打断的程序可以在后来可以再次被调度恢复执行。

在操作系统里，打断正在执行的任务有两种常见的 Context Switch (上下文切换) 机制，

- Interrupt (中断)或 Exception (异常) 处理

  很多英文技术文档和讨论里把这种类型的打断动作叫做 Pin，意思就是当前的任务没有被切换走，而是被 Pin 住不能动弹了。
  这种打断不像 Context Switch 那样，涉及到地址空间的切换。而且这种打断通畅和处理器和外围硬件的中断机制有关。
  依赖于不同操作系统的实现，可能中断或者异常处理程序有自己的独立内核栈，例如当前 Linux 版本在32位和64位 x86 上的实现；
  也可能使用任务当前的内核栈，例如早期 Linux 在32位 x86 上的实现。

  以 Intel 的 x64 处理器为例，当外设产生中断后，CPU 通过 Interrupt Gate (中断门) 打断了当前任务的执行。
  此时，不论正在执行的任务处于用户态还是内核态，中断门都会无条件保存当前任务执行的寄存器执行上下文。
  这些寄存器里就有当前任务下一条待执行的代码段指令寄存器 `CS:RIP` 和当前任务栈指针寄存器 `SS:RSP`。
  而新的中断上下文的代码段指令寄存器 `CS:RIP` 的值，早由系统启动时由 x86 的 IDT (中断描述符表) 相关的初始化代码设置为所有外设中断的公共 IRQ Routine (中断处理例程) 函数。
  在 Linux 3.19 的这个公共中断处理例程 entry_64.S 的 irq_entries_start 汇编函数里，
  [SAVE_ARGS_IRQ 宏](https://github.com/torvalds/linux/blob/v3.19/arch/x86/kernel/entry_64.S#L782)会把存储在 per-CPU 变量 irq_stack_ptr 里的内核 IRQ Stack (中断栈) 赋值给 SS:RSP。
  这样一来，一个完整的中断上下文切换就由 CPU 和中断处理例程共同协作完成。中断执行完毕，从中断例程的返回过程则会利用之前保存的上下文，恢复之前被打断的任务。

  x64 的异常机制与中断机制类似，都利用了 IDT 来完被打断任务的 `CS:RIP` 和 `SS:RSP` 的保存，但 IDT 表里异常的公共入口函数却是不同的函数。
  而且在这个函数的汇编实现里，切换到内核 IRQ Stack 的代码是借助硬件里预先被内核初始化好的 IST (中断服务表) 里保存的 `SS:RSP` 的值，这是与一般外设中断处理的不同之处。

  另外，x64 和 x32 的 IDT 机制在从内核态进入到中断门时，硬件在是否把当前任务的 `SS:RSP` 寄存器压栈的处理上有明显差别。
  此外，IDT 在初始化时，IDT 描述符里的 IST 选择位如果非零，则意味着内核 IRQ Stack 的切换是要由内核代码借助 IST 实现。
  但如果 IDT 描述符的 IST 选择位是零，则内核的 IRQ Stack 切换由内核代码借助 per-CPU 的内核中断栈变量实现。

  由于主题和篇幅限制，这里不会详细介绍中断的上下文切换机制。了解 x86 平台中断和异常的上下文切换机制，需要对 x86 处理器的硬件规范有所了解。
  [Intel Intel 64 and IA-32 Architectures Software Developer's Manual Volume 3](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html)
  里的 **6.14 EXCEPTION AND INTERRUPT HANDLING IN 64-BIT MODE** 章节里有硬件的详细介绍，尤其详细说明了32位和64位，以及中断和异常的详细差异。

- 任务 Context Switch (上下文切换)

  一般调度器领域所引用的 Context Switch 这个词往往特指普通任务之间的上下文切换。
  调度器的任务上下文切换主要做两件事，通用寄存器的切换(内核栈切换随寄存器切换而完成)和地址空间的切换(通过特殊寄存器切换完成)。

TBD

### 2. Preemption 的主要原因

### 3. Preemption 发生的时机

#### 3.1 User Preemption

#### 3.2 Kernel Preemption

### 4. schedule 函数
