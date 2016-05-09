---
layout: post
title: Linux kdb, kgdb, gdb - 2
description: Linux kernel could be debugged by kgdb via serial console. For console server, that need some sepcial settings.
categories: [English, Software]
tags:
- [kgdb, kernel, linux]
---

>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

* content
{:toc}

## 1. Background

Lots of kernel panics could happen without a valid kernel core file. 
For example, for IO/file system/early boot/repeatable panic bugs, the only way is using printk or kdb/kgdb to debug the problems.

There are two big problems for kdb debugging,

1. Kdb in current Linux mainline became useless

   In mainline, kdb has less features than original kdb private patch. It is just a front end of new kernel debugger - kgdb.
   Now kdb becomes useless because the disassembly command was removed. In recent mainline code changes, more kdb commands were removed.
 
2. Kdb could not understand C data structure

   For example, if you want to check input arguments of an API, it doesn’t understand the C data structures. 
   The API arguments checking become the raw memory dump which is not friendly to most of us. 

   The other big advantage of kgdb is, if we specify the source code path, we can do source code level debugging by kgdb.

## 2. How to debug Linux kernel by kgdb via console server

1. Terminal server setting

   My server’s terminal server IP is 10.32.228.250, port is 9017.
   If terminal server port need login with password, we need disable the login prompt.
   We need change it to “RAW TCP” mode instead of telnet or SSH mode.

2. Start agent-proxy to multiplex input/output of terminal server

   The agent-proxy is now available from:

		# git clone http://git.kernel.org/pub/scm/utils/kernel/kgdb/agent-proxy.git
		# cd agent-proxy ; make
		#./agent-proxy 2223^2222 10.32.228.250 9017

3. Access Linux server via console

	Connect to agent-proxy,

		# telnet 127.0.0.1 2223
		
	Enable kdb and trigger a crash dump for this demo,
		
		# echo ttyS0 > /sys/module/kgdboc/parameters/kgdboc
		# echo g >/proc/sysrq-trigger
		# echo c >/proc/sysrq-trigger
		
	Kernel panicked and dropped into kdb,
		
		# (E6)[       868.670037] SysRq : Trigger a crash
		(U1)(MSG-KERN-00009):[       868.721408] BUG: Unable to handle kernel NULL pointer dereference at           (null)
		(E1)[       868.842505] IP: [<ffffffff8122ac03>] sysrq_handle_crash+0x16/0x20
		(E4)[       868.925153] PGD 425f02067 PUD 42307a067 PMD 0
		(U0)(MSG-KERN-00005):[       868.988340] Oops: 0002 [#1] SMP
		Kdb>
		
	Switch to kgdb mode by using kgdb commands,
		
		Kdb>kgdb
		
		(E2)[       869.054558] KGDB: waiting... or $3#33 for KDB
		
4.	Debugging panic issue by using remote gdb.
		
	Start gdb by specifying location of vmlinux (with debug symbol),
		
		$ gdb /workspace/vmlinux-*
		GNU gdb Fedora (6.8-27.el5)
		Copyright (C) 2008 Free Software Foundation, Inc.
		License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
		This is free software: you are free to change and redistribute it.
		There is NO WARRANTY, to the extent permitted by law.  Type "show copying"
		and "show warranty" for details.
		This GDB was configured as "x86_64-redhat-linux-gnu"...
		
	Connect to kgdb server,
		
		(gdb) tar remote 127.0.0.1:2222
		Remote debugging using 127.0.0.1:2222
		sysrq_handle_crash (key=99) at drivers/tty/sysrq.c:134
		
		
	Specify the source code location. This is optional if you don’t need look into source code.
	Without source code you also can know the panic location and the arguments of each API.
		
		(gdb) directory <path_to_linux_src>/linux-3.2/
		Source directories searched: <path_to_linux_src>/linux-3.2:$cdir:$cwd
		
		(gdb) list  134
		129     {
		130             char *killer = NULL;
		131
		132             panic_on_oops = 1;      /* force panic */
		133             wmb();
		134             *killer = 1; 
		135     }
		136     static struct sysrq_key_op sysrq_crash_op = {
		137             .handler        = sysrq_handle_crash,
		138             .help_msg       = "Crash",
		
	Get the backtrace of the panic, the argument of each API in backtrace is parsed out,
		
		(gdb) bt
		#0  sysrq_handle_crash (key=99) at drivers/tty/sysrq.c:134
		#1  0xffffffff8122b1c5 in __handle_sysrq (key=99, check_mask=false) at drivers/tty/sysrq.c:522
		#2  0xffffffff8122b294 in write_sysrq_trigger (file=<value optimized out>, buf=<value optimized out>, count=2, ppos=<value optimized out>)
		    at drivers/tty/sysrq.c:870
		#3  0xffffffff8112f754 in proc_reg_write (file=0xffff88040f3210c0, buf=<value optimized out>, count=<value optimized out>, ppos=<value optimized out>)
		    at fs/proc/inode.c:200
		#4  0xffffffff810e822d in vfs_write (file=0xffff88040f3210c0, buf=0x7f3dce849000 "c\nyS0\n", count=2, pos=0xffff88042335ff58) at fs/read_write.c:435
		#5  0xffffffff810e8492 in sys_write (fd=<value optimized out>, buf=0x7f3dce849000 "c\nyS0\n", count=<value optimized out>) at fs/read_write.c:487
		#6  0xffffffff8137d4eb in system_call_fastpath ()
		#7  0x0000000000000246 in irq_stack_union ()
		#8  0x00007f3dce4bf620 in ?? ()
		#9  0x00007f3dce83f6e0 in ?? ()
		#10 0x000000000000000a in irq_stack_union ()
		#11 0x0000000000000001 in irq_stack_union ()
		#12 0x0000000000000002 in irq_stack_union ()
		#13 0x0000000000000001 in irq_stack_union ()
		#14 0x00007f3dce34ad50 in ?? ()
		#15 0x0000000000000033 in irq_stack_union ()
		#16 0x0000000000000283 in irq_stack_union ()
		#17 0x00007ffff9161f30 in ?? ()
		#18 0x000000000000002b in irq_stack_union ()
		#19 0x0000000000000000 in ?? ()

	Now you can debug Linux kernel by gdb remotely. Enjoy it!

## 3. Related Reading

* [Linux kdb, kgdb, gdb - 1](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-1/)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
