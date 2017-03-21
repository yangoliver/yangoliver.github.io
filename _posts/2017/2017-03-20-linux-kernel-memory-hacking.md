---
layout: post
title: Linux Kernel Memory Hacking
description: How to use crash and systemtap hacking kernel memory.
categories: [Chinese, Software]
tags:
- [crash, trace, kernel, linux]
---

>The content reuse need include the original link: <http://oliveryang.net>

* content
{:toc}

### 1. 问题

修改正在运行的 Linux 内核的内存是在内核开发中常见的需求之一。通过修改内核内存，我们可以轻松地实现内核开发里的单元测试，或者注入一个内核错误。
虽然修改内核内存有很多方式，例如使用 systemtap 脚本可以实现一些简单的内核内存的修改，但是论灵活性和安全性，还是要数 Linux 的 crash 工具。

如果您不熟悉 Linux Crash 工具，请阅读 [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background/) 这篇文章。第 4 小节还有大量其它链接可以参考。

Linux crash 工具提供了简单的 `wr` 命令，可以轻松修改指定的虚拟内存地址的内存。而且，crash 可以轻松解析内核的数据结构，计算出结构成员，链表成员的地址偏移。
但在 RHEL 7 上，使用 crash 修改内存，却报告如下错误，

	crash> wr panic_on_oops 1
	wr: cannot write to /dev/crash!

### 2. 原因

Linux crash 自带了一个内存驱动 (`/dev/crash`)，用于支持对内核内存的操作。
但 [crash 的代码](https://github.com/crash-utility/crash/blob/7.1.8/memory_driver/crash.c#L252) 并没有提供写内存的支持。

此时，我们可以利用实现了写操作的 `/dev/mem` 设备做为 `/dev/crash` 替换来解决问题，

	$ sudo crash /dev/mem

在 RHEL 和一些其它 Linux 发行版，因为系统默认打开了 `CONFIG_STRICT_DEVMEM` 编译选项，从而限制了 `/dev/mem` 驱动的使用，

	crash: this kernel may be configured with CONFIG_STRICT_DEVMEM, which
		renders /dev/mem unusable as a live memory source.
	crash: trying /proc/kcore as an alternative to /dev/mem

于是，crash 提示使用 `/proc/kcore`，这种方式也无法提供对内存的修改操作。

### 3. 解决

如果阅读内核源码，可以看到，`CONFIG_STRICT_DEVMEM` 的限制主要依赖如下函数的返回值，

	int devmem_is_allowed(unsigned long pagenr)
	{
		if (pagenr <= 256)
			return 1;
		if (!page_is_ram(pagenr))
			return 1;
		return 0;
	}

如果我们能不重新编译内核，就让这个函数的返回永远是 1，则可以轻松绕过这个限制。基于此分析，我们可以用一行 systemtap 命令搞定这件事情，

	$ sudo stap -g -e 'probe kernel.function("devmem_is_allowed").return { $return = 1 }'


运行完上述命令后，在另一个终端执行 crash 命令测试我们的内存修改命令 (例子里修改了 panic_on_oops 的内核全局变量)，一切工作正常，

	crash> wr panic_on_oops 1
	crash> p panic_on_oops
	panic_on_oops = $1 = 1

至此，我们也可以想到，利用 systemtap，通过修改内核函数的返回值，来做内核开发的单元测试和错误注入也是轻而易举的。

### 4. 延伸阅读

* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash - my patches](http://oliveryang.net/2015/06/linux-crash-my-patches/)
* [Linux Crash - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
* [Linux Crash - coding notes](http://oliveryang.net/2015/07/linux-crash-coding-notes/)
* [Linux Perf Tools Tips](http://oliveryang.net/2016/07/linux-perf-tools-tips/)
* [SystemTap Beginners Guide](https://www.sourceware.org/systemtap/SystemTap_Beginners_Guide/index.html)
* [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf)
