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

#### 2.1.5 How to use kprobe event via perf CLI?

Below example showed that how to use kprobe to get the 2nd arguments of `do_unlinkat`,

	$ sudo perf probe --add 'do_unlinkat pathname=+0(%si):string'
	$ sudo perf record -e probe:do_unlinkat –aR sleep 3600
	$ sudo perf script

The syntax of kprobe event could be found from [Documentation/trace/kprobetrace.txt](https://github.com/torvalds/linux/blob/master/Documentation/trace/kprobetrace.txt).

### 2.2 SystemTap

#### 2.2.1 How to run systemtap with customized kernel

In short, we could rebuild systemtap and kernel to make it work together. Please refer to [This article](https://www.ibm.com/support/knowledgecenter/linuxonibm/liaai.systemTap/liaaisystapcustom.htm).

#### 2.2.2 Where can I find systemtap example scripts?

For systemtap example scripts, there are two ways,

- Visit [public example index page](https://sourceware.org/systemtap/examples)
- Get it via local package installation

	  $ sudo yum install -y systemtap
	  $ cd /usr/share/doc/systemtap-client-2.8/examples

Reading example scripts is the best way to learn systemtap. [SystemTap Beginners Guide](https://www.sourceware.org/systemtap/SystemTap_Beginners_Guide/index.html) is a good reference.

#### 2.2.3 How to run pre-built systemtap module directly?

First, build the systemtap script by running `stap -k` option,

	$ sudo stap -k iostats.stp
	...[snipped]...
	Keeping temporary directory "/tmp/stapKI1aZ3"

Then, find the module from temporary directory, and run it by `staprun`,

	$ sudo staprun /tmp/stapKI1aZ3/stap_13235.ko

#### 2.2.4 How to get input arguments and local variables?

The `-L` option showed the source code information, input arguments, and local variables,

$ sudo stap -L 'kernel.function("do_unlinkat")'
kernel.function("do_unlinkat@fs/namei.c:3857") $dfd:int $pathname:char const* $path:struct path $last:struct qstr $type:int $delegated_inode:struct inode*

The `-e` option could be used in one liner command, and we could print 2nd argument of `do_unlinkat` by following way,

$ sudo stap -e 'probe kernel.function("do_unlinkat") { printf("%s \n", kernel_string($pathname))} '

#### 2.2.5 Address unwind data issue for a module

Got following warning messages while running below SystemTap one line command,

	$ sudo stap -e 'probe kernel.function("generic_make_request") { print_backtrace() }'
	 0xffffffff81317350 : generic_make_request+0x0/0x1d0 [kernel]
	 0xffffffff81317597 : submit_bio+0x77/0x150 [kernel]
	 0xffffffffa02b5d6a [xfs]
	 0xffffffffa02b7913 [xfs] (inexact)
	 0xffffffffa02b7664 [xfs] (inexact)
	 0xffffffffa02b7913 [xfs] (inexact)
	 0xffffffffa02b86df [xfs] (inexact)
	 0xffffffffa02b86df [xfs] (inexact)
	 0xffffffffa02e4325 [xfs] (inexact)
	 0xffffffffa02e40a0 [xfs] (inexact)
	 0xffffffffa02e40a0 [xfs] (inexact)
	 0xffffffff810a8cd8 : kthread+0xd8/0xf0 [kernel] (inexact)
	 0xffffffff816bb882 : ret_from_fork+0x22/0x40 [kernel] (inexact)
	 0xffffffff810a8c00 : kthread+0x0/0xf0 [kernel] (inexact)
	...[snipped...]
	WARNING: Missing unwind data for a module, rerun with 'stap -d xfs'

We could see there is no symbol for xfs module. The issue could be fixed by re-running below command,

	$ sudo stap -d xfs -e 'probe kernel.function("generic_make_request") { print_backtrace() }'

Or using `--all-modules` option to add unwind/symbol data for all loaded kernel objects,

	$ sudo stap --all-modules -e 'probe kernel.function("generic_make_request") { print_backtrace() }'

The `--all-modules` could increase the module size built by stap, `-d` should be better way to address the issue.

## 3. References

* [SystemTap Beginners Guide](https://www.sourceware.org/systemtap/SystemTap_Beginners_Guide/index.html)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [perf-tools github](https://github.com/brendangregg/perf-tools)
