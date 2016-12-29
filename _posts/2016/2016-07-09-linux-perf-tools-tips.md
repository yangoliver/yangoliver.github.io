---
layout: mindmap
title: Linux Perf Tools Tips
description: Linux perf tools tips
categories: [English, Software]
tags: [perf, trace, kernel, linux, solaris]
---

>The content reuse need include the original link: <http://oliveryang.net>

* content
{:toc}

## 1. About

I used to be a Solaris [DTrace](https://en.wikipedia.org/wiki/DTrace) fan. With helps of DTrace, people could easily understand how OS kernel working inside.
After moving to Linux world, I found that Linux has a rich set of features related to dynamic tracing, like perf, ftrace, systemtap, kprobe, uprobe, tracepoint, eBPF...and so on.

At beginning, I did see the big gaps in Linux kernel dynamic tracing area. However, more and more new features got integrated into Linux recent years.
Especially, with eBPF available in Linux 4.x kernel, I believe Linux dynamic tracing already performs better than Solaris DTrace.

Linux has already changed the OS world, whereas Solaris is going to die.
Even today, the design and usage of DTrace are still elegant and outstanding, but nobody could prevent the trend of Open Source.

This article is about Linux trace tools introduction. Especially, the new dynamic trace tools which support turn on/off dynamic probes or trace events on the fly.

## 2. Big Picture

Today, there are many dynamic trace tools in Linux. Many people don't have clear ideas or concepts about the positions of different Linux trace tools.
Below **Conceptual View** of Linux trace tools could give you a high level overview about the positions of different Linux trace tools.

<img src="/media/images/2016/linux_trace_tools.png" width="100%" height="100%" />

You may find that the underlying tools in above picture are the building blocks of other trace tools.
Below mindmap could give you a big picture regarding to the classification of these building blocks.

<pre class="km-container" minder-data-type="markdown" style="width: 100%;height: 250px">

- Trace Events
  - Software Events
    - Predefined
      - [Mcount](https://github.com/torvalds/linux/blob/master/Documentation/trace/ftrace.txt)
      - [Tracepoint](https://github.com/torvalds/linux/blob/master/Documentation/trace/tracepoints.txt)
    - Dynamic
      - [Kprobe](https://github.com/torvalds/linux/blob/master/Documentation/trace/kprobetrace.txt)
      - [Uprobe](https://github.com/torvalds/linux/blob/master/Documentation/trace/uprobetracer.txt)
  - Hardware Events
    - [Perf Events (PMU)](https://perf.wiki.kernel.org/index.php/Main_Page)

</pre>

Linux trace tools give us a good opportunity to understand system behaviors deeply and quickly. In last month, I gave a presentation in community.
In my talk, I shared my expericences on Linux perf tools usage.
For more information, please download the slides - [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf). 

## 3. Tips

This section is just a collection of Linux perf tips instead of a well structured descriptions. The contents of the section might be changed per my daily updates.

### 3.1 Perf

#### 3.1.1 Perf cannot find external module symbols

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

#### 3.1.2 Perf probe external module symbols

List, add a kernel probe for a module, and record, report the profiling the results

	$ perf probe -F -m /lib/modules/4.6.0/kernel/drivers/block/sampleblk.ko

	$ perf probe -m /lib/modules/4.6.0/kernel/drivers/block/sampleblk.ko -a sampleblk_request

	$ perf record -e probe:sampleblk_request -aRg sleep 1

	$ perf report

#### 3.1.3 Show tracepoints in a kernel subsystem

List all kernel block layer tracepoints,

	$ sudo perf list subsys block:*

#### 3.1.4 Show kernel & module available probe points

List all probe points in kernel,

	$ perf probe -F

List all probe points in a module,

	$ perf probe -F -m ext4

All of above probe points could be also used by ftrace and other kprobe based tools. By default, all kernel and module APIs could be listed as probe points.

#### 3.1.5 How to add a dynamic kernel probe event via perf CLI?

In Linux kernel, dynamic kernel probe event is supported by kprobe. Perf CLI could be its front-end.
First, get the what lines could be probed by perf,

	$ sudo perf probe -L do_unlinkat | head -n2
	<do_unlinkat@/lib/modules/4.6.0-rc3+/build/fs/namei.c:0>
    0  static long do_unlinkat(int dfd, const char __user *pathname)

Second, query probeable input arguments and local variable,

	$ sudo perf probe -V do_unlinkat
	Available variables at do_unlinkat
	        @<do_unlinkat+0>
	                char*   pathname
	                int     dfd
	                int     type
	                struct inode*   delegated_inode
	                struct path     path
	                struct qstr     last

Last, add probe and start tracing,

	$ perf probe --add 'do_unlinkat pathname:string'
	$ sudo perf record -e probe:do_unlinkat –aR sleep 3600
	$ sudo perf script

The syntax of kprobe event could be found from [Documentation/trace/kprobetrace.txt](https://github.com/torvalds/linux/blob/master/Documentation/trace/kprobetrace.txt).

#### 3.1.6 "Failed to load kernel map" or "Failed to open debuginfo file" error messages

On my customized Linux kernel, I ran into above errors even, I specified the correct kernel debug-info binaries with -k option, why?

	# perf probe -nv 'vfs_read:0 count' -k /vmlinux-ddr550797 -s ~/linux-3.2/
	probe-definition(0): vfs_read:0 count -k /vmlinux-ddr550797 -s /root/linux-3.2/
	symbol:vfs_read file:(null) line:0 offset:0 return:0 lazy:(null)
	parsing arg: count into count
	parsing arg: -k into -k
	parsing arg: /vmlinux-ddr550797 into /vmlinux-ddr550797
	parsing arg: -s into -s
	parsing arg: /root/linux-3.2/ into /root/linux-3.2/
	5 arguments
	Looking at the vmlinux_path (6 entries long)
	Failed to load kernel map.
	Failed to find path of kernel module.
	Failed to open debuginfo file.
	  Error: Failed to add events. (-2)

Using strace could get the root causes,

	# strace perf probe -nv 'vfs_read:0 count' -k /vmlinux-ddr550797 -s ~/linux-3.2/

	[...snipped...]
	write(2, "Looking at the vmlinux_path (6 e"..., 45Looking at the vmlinux_path (6 entries long)
	) = 45
	open("vmlinux", O_RDONLY)               = -1 ENOENT (No such file or directory)
	open("/boot/vmlinux", O_RDONLY)         = -1 ENOENT (No such file or directory)
	open("/boot/vmlinux-3.2.33-ddr552094", O_RDONLY) = -1 ENOENT (No such file or directory)
	open("/lib/modules/3.2.33-ddr552094/build/vmlinux", O_RDONLY) = -1 ENOENT (No such file or directory)
	open("/usr/lib/debug/lib/modules/3.2.33-ddr552094/vmlinux", O_RDONLY) = -1 ENOENT (No such file or directory)
	write(2, "Failed to load kernel map.\n", 27Failed to load kernel map.
	) = 27
	write(2, "Failed to find path of kernel mo"..., 38Failed to find path of kernel module.
	) = 38
	write(2, "Failed to open debuginfo file.\n", 31Failed to open debuginfo file.
	) = 31
	write(2, "  Error: Failed to add events. ("..., 36  Error: Failed to add events. (-2)
	) = 36
	exit_group(254)                         = ?
	+++ exited with 254 +++

Then we know that we could create a symbol link or make install kernel with debug-info to one of directories of above outputs.

	# mkdir /lib/modules/3.2.33-ddr552094/build/
	# ln -s /vmlinux-ddr552094 /lib/modules/3.2.33-ddr552094/build/vmlinux

With the workaround above, the perf command could work now.

#### 3.1.7 How to add a dynamic user space probe event via perf CLI?

User space probe needs Uprobes support in both kernel and perf CLI.

First, you should make sure user space debuginfo package got installed. To trace glibc API，needs install glibc debuginfo packages.
On RHEL, glibc debuginfo packages could be installed with below command,

	$ sudo debuginfo-install glibc

Second, you could double check available dynamic probe points,

	$ sudo perf probe -x /lib64/libc.so.6 -F | grep fopen64
	fopen64

Third, list the input arguments and local varibales,

	[yango@localhost ~]$ sudo perf probe -x /lib64/libc.so.6 -L fopen64
	<_IO_new_fopen@/usr/src/debug/glibc-2.17-c758a686/libio/iofopen.c:0>
	      0  _IO_new_fopen (filename, mode)
	              const char *filename;
	              const char *mode;
	      3  {
	      4    return __fopen_internal (filename, mode, 1);
	         }

	         #ifdef _LIBC

Last, add the probe, record trace and display trace results,

	$ sudo perf probe -x /lib64/libc.so.6 -V fopen64
	Available variables at fopen64
	        @<_IO_new_fopen+0>
	                char*   filename
	                char*   mode

	$ sudo perf probe -x /lib64/libc.so.6 -a 'fopen64 filename:string'
	$ sudo ./perf record -e probe_libc:fopen64 -aR sleep 60
	$ sudo ./perf script
	irqbalance   568 [001] 54683.806403: probe_libc:fopen64: (7f7289620a00) filename_string="/proc/interrupts"
	irqbalance   568 [001] 54683.806753: probe_libc:fopen64: (7f7289620a00) filename_string="/proc/stat"
	      perf 13914 [001] 54688.046240: probe_libc:fopen64: (7f47ed015a00) filename_string="/proc/self/status"

The syntax of kprobe event could be found from [Documentation/trace/uprobetracer.txt](https://github.com/torvalds/linux/blob/master/Documentation/trace/uprobetracer.txt)

#### 3.1.8 Can't show user process symbol correctly in call graph?

Using perf record and perf script couldn't show the call graph with correct symbol correctly (marked by unknown),

	$ sudo perf record -a -g -e block:block_rq_insert sleep 10

	$ sudo perf script
	fio 71005 [000] 977641.575503: block:block_rq_insert: 253,1 W 0 () 3510 + 255 [fio]
	                  5111e1 __elv_add_request (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  518e64 blk_flush_plug_list (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  51910b blk_queue_bio (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  517453 generic_make_request (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  517597 submit_bio (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                   107de ext4_io_submit ([ext4])
	                    c6bc ext4_writepages ([ext4])
	                  39cd3e do_writepages (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  390b66 __filemap_fdatawrite_range (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  3d5d96 sys_fadvise64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  203c12 do_syscall_64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                  8bb721 return_from_SYSCALL_64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
	                   ebd4d posix_fadvise64 (/usr/lib64/libc-2.17.so)
	                       0 [unknown] ([unknown])

By using dwarf method to collect call graph information, it could show the fio symbol in user space stack trace，

	$ sudo perf record -a -g --call-graph dwarf -e block:block_rq_insert sleep 10
	
    $ sudo perf script | head -n 20
    fio 73790 [000] 1011438.379090: block:block_rq_insert: 253,1 W 0 () 3510 + 255 [fio]
                  5111e1 __elv_add_request (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  518e64 blk_flush_plug_list (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  51910b blk_queue_bio (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  517453 generic_make_request (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  517597 submit_bio (/lib/modules/4.6.0-rc3+/build/vmlinux)
                   107de ext4_io_submit ([ext4])
                    c6bc ext4_writepages ([ext4])
                  39cd3e do_writepages (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  390b66 __filemap_fdatawrite_range (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  3d5d96 sys_fadvise64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  203c12 do_syscall_64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
                  8bb721 return_from_SYSCALL_64 (/lib/modules/4.6.0-rc3+/build/vmlinux)
            7fd1e61d7d4d posix_fadvise64 (/usr/lib64/libc-2.17.so)
                  4303b3 file_invalidate_cache (/usr/local/bin/fio)
                  41a79b td_io_open_file (/usr/local/bin/fio)
                  43f40d get_io_u (/usr/local/bin/fio)
                  45ad89 thread_main (/usr/local/bin/fio)
                  45cffc run_threads (/usr/local/bin/fio)
    [...snipped...]


### 3.2 SystemTap

#### 3.2.1 How to run systemtap with customized kernel

In short, we could rebuild systemtap and kernel to make it work together. Please refer to [This article](https://www.ibm.com/support/knowledgecenter/linuxonibm/liaai.systemTap/liaaisystapcustom.htm).

#### 3.2.2 Where can I find systemtap example scripts?

For systemtap example scripts, there are two ways,

- Visit [public example index page](https://sourceware.org/systemtap/examples)
- Get it via local package installation

	  $ sudo yum install -y systemtap
	  $ cd /usr/share/doc/systemtap-client-2.8/examples

- Access from systemtap source code repository

	  $ git clone http://sourceware.org/git/systemtap.git
	  $ cd ~/systemtap/testsuite/systemtap.examples

Reading example scripts is the best way to learn systemtap. [SystemTap Beginners Guide](https://www.sourceware.org/systemtap/SystemTap_Beginners_Guide/index.html) is a good reference.

#### 3.2.3 How to run pre-built systemtap module directly?

First, build the systemtap script by running `stap -k` option,

	$ sudo stap -k iostats.stp
	...[snipped]...
	Keeping temporary directory "/tmp/stapKI1aZ3"

Then, find the module from temporary directory, and run it by `staprun`,

	$ sudo staprun /tmp/stapKI1aZ3/stap_13235.ko

#### 3.2.4 How to get input arguments and local variables?

The `-L` option showed the source code information, input arguments, and local variables,

	$ sudo stap -L 'kernel.function("do_unlinkat")'
	kernel.function("do_unlinkat@fs/namei.c:3857") $dfd:int $pathname:char const* $path:struct path $last:struct qstr $type:int $delegated_inode:struct inode*

The `-e` option could be used in one liner command, and we could print 2nd argument of `do_unlinkat` by following way,

	$ sudo stap -e 'probe kernel.function("do_unlinkat") { printf("%s \n", kernel_string($pathname))} '

#### 3.2.5 Address unwind data issue for a module

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

#### 3.2.6 Error: probe overhead exceeded threshold

Systemtap will report error while a probe couldn't return within a time threshold.

	$ sudo ./kgdb.stp
	ERROR: probe overhead exceeded threshold
	WARNING: Number of errors: 1, skipped probes: 0
	WARNING: /home/yango/systemtap-3.1-125278/bin/staprun exited with status: 1
	Pass 5: run failed.  [man error::pass5]

There are two ways to bypass the problem,

	sudo stap -g --suppress-time-limits ./kgdb.stp

Or,

	sudo stap -DSTP_NO_OVERLOAD -v -g ./kgdb.stp

## 4. References

* [Using Linux Trace Tools - for diagnosis, analysis, learning and fun](https://github.com/yangoliver/mydoc/blob/master/share/linux_trace_tools.pdf)
* [SystemTap Beginners Guide](https://www.sourceware.org/systemtap/SystemTap_Beginners_Guide/index.html)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [perf-tools github](https://github.com/brendangregg/perf-tools)
* [Linux Block Driver - 2](http://oliveryang.net/2016/07/linux-block-driver-basic-2/)
* [Linux Block Driver - 3](http://oliveryang.net/2016/08/linux-block-driver-basic-3/)
