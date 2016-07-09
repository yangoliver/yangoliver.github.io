---
layout: post
title: Linux Perf Tools Tips
description: Linux perf tools tips
categories: [English, Software]
tags: [perf, trace, kernel, linux]
---

>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

* content
{:toc}

## 1. About

I used to be a Solaris [DTrace](https://en.wikipedia.org/wiki/DTrace) fan. With helps of DTrace, people could easily understand how OS kernel working inside.
After moving to Linux world, I found that Linux has a rich set of features related to dynamic tracing, like perf, ftrace, systemtap, kprobe, uprobe, tracepoint, eBPF...and so on.

At beginning, I did see the big gaps in Linux kernel dynamic tracing area. However, more and more new features got integrated into Linux recent years.
Especially, with eBPF available in Linux 4.x kernel, I believe Linux dynamic tracing already performs better than Solaris DTrace.

Linux has already changed the OS world, whereas Solaris is going to die.
Even today, the design and usage of DTrace are still elegant and outstanding, but nobody could prevent the trend of Open Source.

This is just a collection of Linux perf tips instead of a well structured article. The contents of the article might be changed per my daily updates.

## 2. Tips

### 2.1 Perf

#### 2.1.1 Perf cannot find external module symbols

When running perf it finds the kernel symbols but it does not find external module symbols. The kernel module was written by me, and loaded by insmod command.
How can I tell perf to find its symbols as well?

Below is the error messages what I got,

	$ sudo perf record -a -g sleep 1
	[ perf record: Woken up 3 times to write data ]
	[sampleblk] with build id 2584800c6deef34fb775fd4272b52cfe084104f1 not found, continuing without symbols
	[ perf record: Captured and wrote 0.873 MB perf.data (4170 samples) ]

Here are the steps to fix the problem,

	$ sudo perf buildid-list
	c7e7169b12d54db66ebe1c7f256e60dc3e9d4ee5 /lib/modules/4.6.0-rc3+/build/vmlinux
	2584800c6deef34fb775fd4272b52cfe084104f1 [sampleblk] >>> Indicates the module need to be installed?
	b9d896cbaf62770a01594bd28aeba43d31aa440b /lib/modules/4.6.0-rc3+/kernel/fs/ext4/ext4.ko

	$ sudo cp ~/ws/lktm/drivers/block/sampleblk/day1/sampleblk.ko /lib/modules/4.6.0-rc3+/kernel/drivers/block/
	$ sudo depmod -a

## 3. References

* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [perf-tools github](https://github.com/brendangregg/perf-tools)
