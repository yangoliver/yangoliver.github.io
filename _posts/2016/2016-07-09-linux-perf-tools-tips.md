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

	$ perf record -a -g sleep 1
	[ perf record: Woken up 3 times to write data ]
	[sampleblk] with build id 2584800c6deef34fb775fd4272b52cfe084104f1 not found, continuing without symbols
	[ perf record: Captured and wrote 0.873 MB perf.data (4170 samples) ]

Here are the steps to fix the problem,

	$ perf buildid-list
	c7e7169b12d54db66ebe1c7f256e60dc3e9d4ee5 /lib/modules/4.6.0/build/vmlinux
	2584800c6deef34fb775fd4272b52cfe084104f1 [sampleblk] >>> Problem?
	b9d896cbaf62770a01594bd28aeba43d31aa440b /lib/modules/4.6.0/kernel/fs/ext4/ext4.ko

	$ cp ./sampleblk.ko /lib/modules/4.6.0/kernel/drivers/block/
	$ depmod -a

#### 2.1.2 Perf probe external module symbols

List, add a kernel probe for a module, and record, report the profiling the results

	$ perf probe -F -m /lib/modules/4.6.0/kernel/drivers/block/sampleblk.ko

	$ perf probe -m /lib/modules/4.6.0/kernel/drivers/block/sampleblk.ko -a sampleblk_request

	$ perf record -e probe:sampleblk_request -aRg sleep 1

	$ perf report

#### 2.1.3 Show tracepoints in a kernel subsystem

List all kernel block layer tracepoints,

	$ sudo perf list subsys block:*

#### 2.1.4 Show kernel & module available probe points

List all probe points in kernel,

	$ perf probe -F

List all probe points in a module,

	$ perf probe -F -m ext4

All of above probe points could be also used by ftrace and other kprobe based tools. By default, all kernel and module APIs could be listed as probe points.

### 2.2 SystemTap

#### 2.1 How to run systemtap with customized kernel

In short, we could rebuild systemtap and kernel to make it work together. Please refer to [This article](https://www.ibm.com/support/knowledgecenter/linuxonibm/liaai.systemTap/liaaisystapcustom.htm).

#### 2.2 Where can I find systemtap example scripts?

For systemtap example scripts, there are two ways,

- Visit [public example index page](https://sourceware.org/systemtap/examples)
- Get it via local package installation

	  $ sudo yum install -y systemtap
	  $ cd /usr/share/doc/systemtap-client-2.8/examples

Reading example scripts is the best way to learn systemtap. [SystemTap Beginners Guide](https://www.sourceware.org/systemtap/SystemTap_Beginners_Guide/index.html) is a good reference.

#### 2.3 How to run pre-built systemtap module directly?

First, build the systemtap script by running `stap -k` option,

	$ sudo stap -k iostats.stp
	...[snipped]...
	Keeping temporary directory "/tmp/stapKI1aZ3"

Then, find the module from temporary directory, and run it by `staprun`,

	$ sudo staprun /tmp/stapKI1aZ3/stap_13235.ko

## 3. References

* [SystemTap Beginners Guide](https://www.sourceware.org/systemtap/SystemTap_Beginners_Guide/index.html)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [perf-tools github](https://github.com/brendangregg/perf-tools)
