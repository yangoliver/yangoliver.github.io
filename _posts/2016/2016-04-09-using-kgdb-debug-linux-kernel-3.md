---
layout: post
title: Using kdb/kgdb debug Linux kernel - 3
description: Linux modules and drivers could be debugged by kgdb. However, there are lots of pitfalls here.
categories: [English, Software]
tags: [kgdb, kernel, linux, network]
---

>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

>The article is still not finished yet. It will be actively updated in recent days.

## Debug kernel modules/drivers by kgdb

In [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/), we knew how to use gdb as client to debug remote Linux kernel via kgdb server.
It would be no problems, if our debug target is kernel. Setting break points in kernel for live control is quite straightforward.
However, if the debug target is existing in a separate kernel module or driver, it may need additional tricks. This article covers the major tricks to debug a kernel module by kgdb.

### 1. Problems

Using kgdb remote debug has two major problems on kernel module debug,

- The gdb client needs to access the debug version of module binaries.

  This requires to install the module debug binaries on gdb client side first.
  For the module built by ourself, it should be quite easy. While debugging on some commercial Linux distributions, the default module binaries are non-debug version.
  We have to follow the method provided by vendors to get the debug version. There is no standard methods here, different vendors have different methods.
  For example, RHEL/CentOS/Fedora uses `debuginfo-install` command to download and install the debug binaries. Whereas, Ubuntu just provides a website for debug binaries download and manual install.
  Anyway, most of Linux distributions don't install the debug binaries by default. Please follow the methods provided by vendors to install debug binaries.

- The gdb client also needs to know kernel module load address.

  Otherwise, gdb couldn't resolve kernel address of module symbols specified in gdb debug instructions. The `add-symbol-file` command could be used here.
  The command accepts the install path of the kernel module debug binaries. It also requires following module load base addresses for different debug purposes,

  * .text section address for major module function symbols, which is mandated.
  * .init.text section address for module init function symbols, which is optional.
  * .exit.text section address for module exit function symbols, which is optional.
  * .data section address for global variable which is optional.
  * .bss section address for static variable which is optional.

  Linux kernel modules follow the ELF specification. The `add-symbol-file` command accepts all these sections base addresses.
  We just cover most popular sections here. For other sections, you may use them for other special purposes.
  Before using the command, user should have clear concepts about which sections base addresses are required for the debug purposes.

After addressing above two problems, the remaining things are mainly module specific. User needs to have enough knowledge regarding to the module they want to debug.

This article gives some real examples on how to use `add-symbol-file` command properly in different debug scenarios.
In these examples, two machine got connected via serial cable or serial console. The gdb client from one machine could connect to another machine if another machine dropped into kgdb debugger.
And gdb client already can set break points in kernel(vmlinux), and control the kernel execution if we want.

Anyway, at this time points, you couldn't set break points in kernel modules or drivers without running `add-symbol-file` command correctly.
If you still have the problems on connecting to kgdb via gdb client, please refer to [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/).

### 2. Module debugging after system boot

This debug scenario assumes that the kernel module need to be debugged after Linux OS already boot successfully.

Linux provides all kernel module section names and addresses from sysfs interfaces: `/sys/module/[module name]/sections/`.
By leveraging sysfs interfaces, the module ELF sections base addresses could be very easily acquired.

Here is an example of debugging Intel e1000 driver after system boot. Our goal is,

	Setting break points in e1000 driver interrupt handler and checking
	driver key data structures.

In fact, all my debug steps were done on two VMs, which got connected by virtual serial console. The OS version is CentOS 7.2.

#### 2.1 Loading e1000 driver symbols

* First, get module ELF sections base addresses

  As system is still functional, the e1000 module ELF section address could be got by sysfs interfaces.
  Per our debug goals, we just need to focus on follow ELF sections,

	  $ cat /sys/module/e1000/sections/.text
	  0xffffffffa0061000
	  $ cat /sys/module/e1000/sections/.bss
	  0xffffffffa007f878
	  $ cat /sys/module/e1000/sections/.data
	  0xffffffffa007d000

  Note that the commands need to be run on debug target machine.

* Second, trigger the kgdb on debug target machine

  Trigger sysrq debugger commands by keyboard or proc file,

	  # echo g >/proc/sysrq-trigger

  We assumed that kgdb is well configured and setting on target machine. In fact, I used CentOS 7.2 Linux, which already enabled kgdb feature by default.
  The only thing is to follow the kgdb document to setup the kgdb before running above command.

* Third, connect to debug target machine via gdb client.

  Under gdb prompt, connect debug target via remote serial console,

	  (gdb) target remote 127.0.0.1:2222
	  Remote debugging using 127.0.0.1:2222
	  kgdb_breakpoint () at kernel/debug/debug_core.c:1043
	  1043 wmb(); /* Sync point after breakpoint */

  Running bt command, it showed that kernel is stopped and dropped into kgdb via sysrq commands,

	  (gdb) bt
	  #0  kgdb_breakpoint () at kernel/debug/debug_core.c:1043
	  #1  0xffffffff8110f68c in sysrq_handle_dbg (key=<optimized out>) at kernel/debug/debug_core.c:802
	  #2  0xffffffff813b9ed2 in __handle_sysrq (key=103, check_mask=<optimized out>) at drivers/tty/sysrq.c:533
	  #3  0xffffffff813ba3af in write_sysrq_trigger (file=<optimized out>, buf=<optimized out>, count=2, ppos=<optimized out>) at drivers/tty/sysrq.c:1030
	  #4  0xffffffff812492ad in proc_reg_write (file=<optimized out>, buf=<optimized out>, count=<optimized out>, ppos=<optimized out>) at fs/proc/inode.c:224
	  #5  0xffffffff811de5cd in vfs_write (file=file@entry=0xffff88003991d200, buf=buf@entry=0x7f43eb414000 "g\n", count=count@entry=2, pos=pos@entry=0xffff88003649bf48) at fs/read_write.c:501
	  #6  0xffffffff811df06f in SYSC_write (count=2, buf=0x7f43eb414000 "g\n", fd=<optimized out>) at fs/read_write.c:549
	  #7  SyS_write (fd=<optimized out>, buf=139929686458368, count=2) at fs/read_write.c:541
	  #8  <signal handler called>

* Last but most important, load e1000 driver debug symbols via gdb client

  Under gdb prompt, running `add-symbol-file` commands with 3 ELF sections base addresses which we got in first step,

	  (gdb) add-symbol-file /usr/lib/debug/lib/modules/3.10.0-327.el7.x86_64/kernel/drivers/net/ethernet/intel/e1000/e1000.ko.debug 0xffffffffa0061000 -s .bss 0xffffffffa007f878 -s .data 0xffffffffa007d000
	  add symbol table from file "/usr/lib/debug/lib/modules/3.10.0-327.el7.x86_64/kernel/drivers/net/ethernet/intel/e1000/e1000.ko.debug" at
	  .text_addr = 0xffffffffa0061000
	  .bss_addr = 0xffffffffa007f878
	  .data_addr = 0xffffffffa007d000
	  (y or n) y
	  Reading symbols from /usr/lib/debug/usr/lib/modules/3.10.0-327.el7.x86_64/kernel/drivers/net/ethernet/intel/e1000/e1000.ko.debug...done.

  Now, gdb can resolve all e1000 module symbols in .text, .bss, .data sections.

#### 2.2 Setting break points in e1000 driver

As gdb already have the e1000 symbols, we can use the symbols directly in debug commands.
For setting break points, gdb provides two ways,

- Software break points
- Hardware break points

In this case, the software breakpoints couldn't work, so we have to use hardware break points,

	(gdb) hbr e1000_intr
	Hardware assisted breakpoint 1 at 0xffffffffa00614a0: file drivers/net/ethernet/intel/e1000/e1000_main.c, line 3753.

We can list the source code of line 3753, it is the entry point of e1000_intr,

	(gdb) list e1000_intr
	3748 * e1000_intr - Interrupt Handler
	3749 * @irq: interrupt number
	3750 * @data: pointer to a network interface device structure
	3751 **/
	3752 static irqreturn_t e1000_intr(int irq, void *data)
	3753 {
	3754 struct net_device *netdev = data;
	3755 struct e1000_adapter *adapter = netdev_priv(netdev);
	3756 struct e1000_hw *hw = &adapter->hw;
	3757 u32 icr = er32(ICR);

Typing continue command could let stopped kernel run again,

	(gdb) c
	Continuing.

As the e1000 driver is actively running, the e1000_intr is called immediately. Kernel got stopped and dropped into the break points: `e1000_intr`,

	Breakpoint 1, e1000_intr (irq=19, data=0xeee <irq_stack_union+3822>) at drivers/net/ethernet/intel/e1000/e1000_main.c:3753
	3753 {

	(gdb) bt
	#0  e1000_intr (irq=19, data=0xeee <irq_stack_union+3822>) at drivers/net/ethernet/intel/e1000/e1000_main.c:3753
	#1  0xffffffff8111c2be in handle_irq_event_percpu (desc=desc@entry=0xffff880036dedd00, action=action@entry=0xffff88003a3dcf00) at kernel/irq/handle.c:142
	#2  0xffffffff8111c49d in handle_irq_event (desc=desc@entry=0xffff880036dedd00) at kernel/irq/handle.c:191
	#3  0xffffffff8111f90a in handle_fasteoi_irq (irq=<optimized out>, desc=0xffff880036dedd00) at kernel/irq/chip.c:461
	#4  0xffffffff81016ecf in handle_irq ()
	#5  0xffffffff81647daf in do_IRQ (regs=0xffff88003d603e38) at arch/x86/kernel/irq.c:201
	#6  <signal handler called>
	#7  0xffffffffffffffbb in ?? ()

#### 2.3 Checking data structure

In general, we can use gdb commands to check any globle and local variables by a symbol name if the `add-symbol-file` command is invoked correctly.

To dump `struct e1000_adapter`, it requires to get address of `struct net_device`, which is acutally casted from second inputs of `e1000_intr`: `void *data`.
Because the stack framework is not fully created at the entry point of e1000_intr, the address of `data` is not showed correctly at that time.
And the `struct e1000_adapter` will be initialized at line 3755.

Now we set second break point(line 3782) as the `struct e1000_adapter` has been initialized at that time,

	(gdb) hbr 3782
	Hardware assisted breakpoint 4 at 0xffffffffa006155a: file drivers/net/ethernet/intel/e1000/e1000_main.c, line 3782.

	(gdb) c
	Continuing.

After running the continue, the e1000 driver stopped at the line 3782,

	Breakpoint 4, e1000_intr (irq=<optimized out>, data=0xffff88003ae4e000) at drivers/net/ethernet/intel/e1000/e1000_main.c:3782
	3782 adapter->total_tx_packets = 0;

Use gdb p command can print the local variable `netdev` directly, you can see it is exactly same with `data` in gdb output above,

	(gdb) p netdev
	$15 = (struct net_device *) 0xffff88003ae4e000

	(gdb) p *netdev
	$16 = {name = "eno16777736\000\000\000\000", name_hlist = {next = 0x0 <irq_stack_union>, pprev = 0xffff88003bc3d378}, ifalias = 0x0 <irq_stack_union>, mem_end = 0, mem_start = 0, base_addr = 0,
	[...snipped...]

At this time point, the `data` address is already showed in backtrace correctly, and `struct e1000_adapter` has been initialized.
We can try to print another local variable `adapter` to get the contents of the struct, but it failed with **optimized out** messages,

	(gdb) p adapter
	$5 = <optimized out>

	(gdb) p adapter->total_tx_packets
	value has been optimized out

The **optimized out** message usually indicate the compiler optimization problem: gdb print command couldn't work due to compiler optimizations.
For this case, if the module is built by ourself, we may choose to change make file to turn off the compiler optimization features.
However, as we have to working on debugging on some production mode environment, there is no way to avoid this situation.
The next section will give us some detailed steps to handle this issue.

#### 2.4 Struggling with compiler optimizations

In order to understand the **optimized out** problem, we have to work at assembly language level.

Run disassembly command to check the assembly code of e1000_intr,

	(gdb) disas e1000_intr
	Dump of assembler code for function e1000_intr:
	   0xffffffffa00614a0 <+0>:	nopl   0x0(%rax,%rax,1)
	   0xffffffffa00614a5 <+5>:	push   %rbp
	   0xffffffffa00614a6 <+6>:	mov    %rsp,%rbp
	   0xffffffffa00614a9 <+9>:	push   %rbx
	   0xffffffffa00614aa <+10>:	mov    %rsi,%rbx
	   0xffffffffa00614ad <+13>:	mov    0xc90(%rsi),%rax	/* struct member reference location A, based on RSI(data address) */
	   0xffffffffa00614b4 <+20>:	mov    0xc0(%rax),%eax
	   0xffffffffa00614ba <+26>:	test   %eax,%eax

	[...snipped...]

If you are familiar with assembly language and AMD64 system V ABI, you may find the locations to reference member of C structure based on `data` address.

Below is the corresponding C code,

	3752 static irqreturn_t e1000_intr(int irq, void *data)
	3753 {
	3754 struct net_device *netdev = data;
	3755 struct e1000_adapter *adapter = netdev_priv(netdev); /* Is it related struct member reference location A? */
	3756 struct e1000_hw *hw = &adapter->hw;

Per AMD64 system V ABI, we knew that RSI register was used stored the second inputs of e1000_intr, which should be address of `data`. It should be also the address of `netdev`.
Per line 3755, the `struct e1000_adapter` address is initialized by `netdev_priv` return value.

Look into `netdev_priv` C code, the `struct e1000_adapter` address should be at the end of `struct net_device` with some alignment adjusts(32 byte alignments).

	1859 static inline void *netdev_priv(const struct net_device *dev)
	1860 {
	1861     return (char *)dev + ALIGN(sizeof(struct net_device), NETDEV_ALIGN);
	1862 }

Below is the `ALIGN` code, which could make sure the return value based on `x` is aways aligned as the byte specified by `a`.
If `x` is already aligned with `a` byte, then it return `x`, otherwise it will increase `x` value to meet the `a` byte alignment requirements.

	1744 #define NETDEV_ALIGN        32

	49 #define ALIGN(x, a)     __ALIGN_KERNEL((x), (a))

	 9 #define __ALIGN_KERNEL(x, a)        __ALIGN_KERNEL_MASK(x, (typeof(x))(a) - 1)
	10 #define __ALIGN_KERNEL_MASK(x, mask)    (((x) + (mask)) & ~(mask))

For e1000 driver case here(line 3755), as size of `struct net_device` already 32 byte aligned, the return value of `netdev_priv` should be,

	base address of data(netdev) + sizeof(struct net_device)

So what is the size of `struct net_device`? We can use gdb sizeof command here,

	(gdb) p /x sizeof(struct net_device)
	$21 = 0x8c0

Per above output, we knew `struct e1000_adapter` address should be,

	vaule of RSI + 0x8c0 =  0x8c0(%rsi)

But the assembly code showed the struct member reference A is `0xc90(%rsi)`. So what is the member referenced here?
In fact, we could got answer by a quick guess, the `0x90(%rsi)` is `struct e1000_hw`, as known as `adapter->hw`.
That could be verified by below gdb calculations,

	(gdb) p &((struct e1000_adapter *)0)->hw
	$22 = (struct e1000_hw *) 0x3d0 <irq_stack_union+976> /* Got member offset of adapter->hw */

	(gdb) p /x 0x8c0+0x3d0	/* base addr of adapter + member offset of hw */
	$23 = 0xc90

Now it is clear why gdb has **optimized out** results, because it merged line 3755 and 3756 into one assembly instruction.
For this reason, if we really want to dump `struct e1000_adapter` contents, we need use address `0x8c0(%rsi)`.

Below command dumped the `struct e1000_adapter` contents based on `0x8c0(%rsi)`, the RSI value is the second parameter value of `e1000_intr` in previous backtrace,

	(gdb) p *(struct e1000_adapter *)(0xffff88003ae4e000+0x8c0)
	$14 = {active_vlans = {0 <repeats 64 times>}, mng_vlan_id = 65535, bd_number = 0, rx_buffer_len = 1522, wol = 0, smartspeed = 0, en_mng_pt = 0, link_speed = 1000, link_duplex = 2, stats_lock = {{
	      rlock = {raw_lock = {{head_tail = 28705206, tickets = {head = 438, tail = 438}}}}}}, total_tx_bytes = 0, total_tx_packets = 0, total_rx_bytes = 180, total_rx_packets = 3, itr = 20000,
	  itr_setting = 3, tx_itr = 1, rx_itr = 1, fc_autoneg = 1 '\001', tx_ring = 0xffff880036f95180, restart_queue = 0, txd_cmd = 2332033024, tx_int_delay = 8, tx_abs_int_delay = 32, gotcl = 0,
	  gotcl_old = 37571, tpt_old = 288, colc_old = 0, tx_timeout_count = 0, tx_fifo_head = 0, tx_head_addr = 0, tx_fifo_size = 0, tx_timeout_factor = 1 '\001', tx_fifo_stall = {counter = 0},
	  pcix_82544 = false, detect_tx_hung = false, dump_buffers = false, clean_rx = 0xffffffffa0061d90 <e1000_clean_rx_irq>, alloc_rx_buf = 0xffffffffa0062310 <e1000_alloc_rx_buffers>,
	  rx_ring = 0xffff880036f951c0, napi = {poll_list = {next = 0xdead000000100100, prev = 0xdead000000200200}, state = 17, weight = 64, gro_count = 0, poll = 0xffffffffa0064810 <e1000_clean>,

    [...snipped...]

### 3. Boot time debugging

TBD

### 4. Related Readings

* [Using kdb/kgdb debug Linux kernel - 1](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-1/)
* [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/)
* [Linux Crash Utility - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash Utility - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
* [Debugger flow control: Hardware breakpoints vs software breakpoints - 1](http://www.nynaeve.net/?p=80)
* [Debugger flow control: Hardware breakpoints vs software breakpoints - 2](http://www.nynaeve.net/?p=81)
