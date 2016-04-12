---
layout: post
title: Using kdb/kgdb debug Linux kernel - 3
description: Linux modules and drivers could be debugged by kgdb. However, there are lots of tricks here. Using gdb scripts could help on debug efficiency.
categories: [English, Software]
tags: [kgdb, kernel, linux, network]
---

>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

## Debug kernel modules/drivers by kgdb

In [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/), we knew how to use gdb as client to debug remote Linux kernel via kgdb.
It would be no problems, if our debug target is kernel. Setting break points in kernel for live control is quite straightforward.
However, if the debug target is existing in a separate kernel module or driver, it may need additional tricks. This article covers the major tricks to debug a kernel module by kgdb.

### 1. Background

Using kgdb has two major problems on kernel module debug,

- The gdb client needs to access the debug version of module binaries.

  This requires to install the module debug binaries on gdb client side first.
  For the module built by ourself, it should be quite easy. While debugging on some commercial Linux distributions, the default module binaries are non-debug version.
  We have to follow the method provided by vendors to get the debug version. There is no standard methods here, different vendors have different methods.
  For example, RHEL/CentOS/Fedora uses `debuginfo-install` command to download and install the debug binaries. Whereas, Ubuntu just provides a website for debug binaries download and manual install.
  Anyway, most of Linux distributions don't install the debug binaries by default. Please follow the methods provided by vendors to install debug binaries.

- The gdb client also needs to know kernel module load address.

  Otherwise, gdb couldn't resolve module symbol address specified in gdb debug instructions. The `add-symbol-file` command could be used here.
  The command accepts the install path of the kernel module debug binaries. It also requires following module ELF section addresses for different debug purposes,

  * .text section address for major module function symbols, which is mandated.
  * .init.text section address for module init function symbols, which is optional.
  * .exit.text section address for module exit function symbols, which is optional.
  * .data section address for global variable which is optional.
  * .bss section address for static variable which is optional.

  Linux kernel modules follow the ELF specification. The `add-symbol-file` command accepts all these sections base addresses.
  We just cover most popular sections here. For the other sections, you may use them for other special purposes.
  Before using the command, user should have clear concepts about which sections base addresses are required for the debug purposes.

After addressing above two problems, the remaining things are mainly module specific. User needs to have enough knowledge regarding to the module they want to debug.

This article gives some real examples on how to use `add-symbol-file` command properly in different debug scenarios.
In these examples, two machine got connected via serial cable or serial console. The gdb client from one machine could connect to another machine if another machine dropped into kgdb debugger.
And gdb client already can set break points in kernel(vmlinux), and control the kernel execution if we want.

Anyway, at this time point, you couldn't set break points in kernel modules or drivers without running `add-symbol-file` command correctly.
If you still have the problems on connecting to kgdb via gdb client, please refer to [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/).

### 2. Module debugging after system boot

This debug scenario assumes that the kernel module need to be debugged after Linux OS already boot successfully.

Linux provides all kernel module section names and addresses from sysfs interfaces: `/sys/module/[module name]/sections/`.
By leveraging sysfs interfaces, the module ELF sections base addresses could be very easily acquired.

Here is an example of debugging Intel e1000 driver after system boot. Our goal is,

	Setting break points in e1000 driver interrupt handler and checking
	driver key data structures.

In fact, all my debug steps were done on my two VMs, which got connected by virtual serial console. The OS version is CentOS 7.2 with debug kernel modules installed.

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

  Note that the commands need to be run on the debug target machine.

* Second, trigger the kgdb on debug target machine

  Trigger sysrq debugger commands by keyboard or proc file,

	  # echo g >/proc/sysrq-trigger

  We assumed that kgdb is well configured and setting on target machine. In fact, I used CentOS 7.2 Linux, which already enabled kgdb feature by default.
  The only thing is to follow the kgdb document to setup the kgdb before running above commands.

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

  Now, gdb can resolve all e1000 module symbols in .text, .bss and .data sections.

#### 2.2 Setting break points in e1000 driver

As gdb already has the e1000 symbols, we can use the symbols directly in debug commands.
For setting break points, gdb provides two ways,

- Software break points

  Debugger will modify the .text or .data section of ELF image in memory, which could finally trigger the debug exceptions(INT 3 on x86) for debugger.

- Hardware break points

  Leverage hardware debug registers(Dr registers on x86) to setup the break points. Usually has better performance but break points number is limited by register numbers (x86's limitation is 4).

If below two Kconfig options are turned on, the software break points could not be setted due to read only protections.

- CONFIG_DEBUG_RODATA

  Write protection for kernel read-only data structures, which is used to catch potential kernel bugs.

- CONFIG_DEBUG_SET_MODULE_RONX

  Set loadable kernel module data sections as NX, and text section as read-only in order to catch potential kernel bugs.

If you could control kernel build, please turn off them for kgdb debugging. On CentOS 7.2, the first option is off, whereas the second option is on.
For this reason, my software break point could work for kernel, but not work for module. So I have to use hardware break points for module debug,

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

In general, we can use gdb commands to check any global and local variables by a symbol name if the `add-symbol-file` command is invoked correctly.

To dump `struct e1000_adapter`, it requires to get address of `struct net_device`, which is actually casted from second inputs of `e1000_intr`: `void *data`.
Because the stack framework is not fully created at the entry point of e1000_intr, the address of `data` is not showed correctly at that time.
And the `struct e1000_adapter` will be initialized at line 3755.

Now we set second break point(line 3782), and the `struct e1000_adapter` has been initialized at that time,

	(gdb) hbr 3782
	Hardware assisted breakpoint 4 at 0xffffffffa006155a: file drivers/net/ethernet/intel/e1000/e1000_main.c, line 3782.

	(gdb) c
	Continuing.

After running the `continue`, the e1000 driver stopped at the line 3782,

	Breakpoint 4, e1000_intr (irq=<optimized out>, data=0xffff88003ae4e000) at drivers/net/ethernet/intel/e1000/e1000_main.c:3782
	3782 adapter->total_tx_packets = 0;

Use gdb `print` command can print the local variable `netdev` directly, you can see it is exactly same with `data` in gdb output above,

	(gdb) p netdev
	$15 = (struct net_device *) 0xffff88003ae4e000

The `netdev` dump showed reasonable as we see the correct NIC interface name of my VM,

	(gdb) p *netdev
	$16 = {name = "eno16777736\000\000\000\000", name_hlist = {next = 0x0 <irq_stack_union>, pprev = 0xffff88003bc3d378}, ifalias = 0x0 <irq_stack_union>, mem_end = 0, mem_start = 0, base_addr = 0,
	[...snipped...]

At this time point, the `data` address is already showed in backtrace correctly, and `struct e1000_adapter` has been initialized.
We can try to print another local variable `adapter` to get the contents of the struct, but it failed with **optimized out** messages,

	(gdb) p adapter
	$5 = <optimized out>

	(gdb) p adapter->total_tx_packets
	value has been optimized out

The **optimized out** message usually indicates the compiler optimization problem: gdb print command couldn't work due to compiler optimizations.
For this case, if the module is built by ourself, we may choose to change make file to turn off the compiler optimization features.
However, as we have to work on a production environment, there is no way to avoid this situation.
The next section will show us some general methods to handle this challenge.

#### 2.4 Struggling with compiler optimizations

The general way to solve the **optimized out** problems is: working at assembly language level.

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

If you are familiar with assembly language and [x86-64 system V ABI](http://www.x86-64.org/documentation/abi.pdf),
you may find the location to reference member of C structure based on `data` address.

Below is the corresponding C code,

	3752 static irqreturn_t e1000_intr(int irq, void *data)
	3753 {
	3754 struct net_device *netdev = data;
	3755 struct e1000_adapter *adapter = netdev_priv(netdev); /* Is it related struct member reference location A? */
	3756 struct e1000_hw *hw = &adapter->hw;

Per x86-64 system V ABI, we knew that RSI register was used stored the second inputs of e1000_intr, which should be address of `data`. It should be also the address of `netdev`.
Per line 3755, the `struct e1000_adapter` address is initialized by `netdev_priv` return value.

Look into `netdev_priv` C code, the `struct e1000_adapter` address should be at the end of `struct net_device` with some alignment adjusts(32 byte alignments).

	1859 static inline void *netdev_priv(const struct net_device *dev)
	1860 {
	1861     return (char *)dev + ALIGN(sizeof(struct net_device), NETDEV_ALIGN);
	1862 }

Below is the `ALIGN` macros, which could make sure its return value based on `x` is aways `a` bytes aligned.
If `x` is already aligned with `a` byte, then it return `x`, otherwise it will increase `x` value to meet the `a` bytes alignment requirement.

	1744 #define NETDEV_ALIGN        32

	49 #define ALIGN(x, a)     __ALIGN_KERNEL((x), (a))

	 9 #define __ALIGN_KERNEL(x, a)        __ALIGN_KERNEL_MASK(x, (typeof(x))(a) - 1)
	10 #define __ALIGN_KERNEL_MASK(x, mask)    (((x) + (mask)) & ~(mask))

For e1000 driver case here(line 3755), as size of `struct net_device` already 32 byte aligned, the return value of `netdev_priv` should be,

	[base address of data(netdeva)] + sizeof(struct net_device)

So what is the size of `struct net_device`? We can use gdb `sizeof` here,

	(gdb) p /x sizeof(struct net_device)
	$21 = 0x8c0

Per above output, we knew `struct e1000_adapter` address should be,

	[vaule of RSI] + 0x8c0 =  0x8c0(%rsi)

But the assembly code showed the struct member reference location A is `0xc90(%rsi)`. So what is the struct member referenced here?
In fact, we could got answer by a quick guess, the `0x90(%rsi)` is `struct e1000_hw`, as known as `adapter->hw`.
That could be verified by below gdb calculations below.

First, we use some tricks to get the `hw` member offset in `struct e1000_adapter`,

	(gdb) p &((struct e1000_adapter *)0)->hw
	$22 = (struct e1000_hw *) 0x3d0 <irq_stack_union+976> /* Got member offset of hw */

Then we could get magic number `0xc90` by below calculation,

	(gdb) p /x 0x8c0+0x3d0	/* base addr of adapter + member offset of hw */
	$23 = 0xc90

Now it is clear why gdb has **optimized out** results, because it merged two lines of C code(line 3755 and 3756) into one memory access instruction.
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

This debug scenario assumes that the kernel module needs to be debugged before the sysfs interfaces ready.
There are two typical cases here,

- Debug module while module is loading.

  For example, debug module init function. At that time, the sysfs entry for this module has not created yet.

- Debug module while system is booting.

  Even module is already loading, but before user can login, the sysfs entry couldn't be accessed.

Here we still use e1000 as example to show how to load e1000 driver symbols during system boot.

#### 3.1 Key data structure for module load

In fact, all module ELF sections information could be found via `struct module` which is the key data structure for each kernel module.
In the structure, the `sect_attrs` member points to data struct `struct module_sect_attrs`, which is used to decribe key attributes for each ELF sections.

	struct module {
		enum module_state state;

		/* Member of list of modules */
		struct list_head list;

		/* Unique handle for this module */
		char name[MODULE_NAME_LEN];

		[...snipped...]

		/* Startup function. */
		int (*init)(void);

		/* If this is non-NULL, vfree after init() returns */
		void *module_init;

		/* Here is the actual code + data, vfree'd on unload. */
		void *module_core;

		/* Here are the sizes of the init and core sections */
		unsigned int init_size, core_size;

		[...snipped...]

		/* Section attributes */
		struct module_sect_attrs *sect_attrs;

		[...snipped...]
	}

In `struct module_sect_attrs`, the member `nsections` indicates how many ELF sections in the module.
The member `attrs` is the array of `struct module_sect_attr`, which defined the section name and base address for each section.

	struct module_sect_attr {	/* array element of struct module_sect_attrs */
		struct module_attribute mattr;
		char *name; /* ELF section name */
		unsigned long address; /* ELF section base address */
	};

	struct module_sect_attrs {
		struct attribute_group grp;
		unsigned int nsections; /* number of section in the array */
		struct module_sect_attr attrs[0]; /* array of struct module_sect_attr */
	};

Anyway, we already could get module's ELF section name and address per a `struct module` address.

Then the next question is, how could we get a valid `struct module` address **before kernel module is initialized**?

In order to get the address before module load, we must to learn the code path to call into module init routine,

	SyS_finit_module->load_module->do_init_module->[module init routine]

Below is the code of do_init_module calling into the module init routine,

	static int do_init_module(struct module *mod)
	{

		[...snipped...]

		/* Start the module */
		if (mod->init != NULL)
			ret = do_one_initcall(mod->init); /* calls into module init routine */
		if (ret < 0) {
			goto fail_free_freeinit;
		}

Per above code path and do_init_module code, we know that the break point at do_init_module will meet below two conditions at same time,

- Can access a valid `struct module` address under this context
- Can stop and invoked proper debug instructions before the module init routine gets called

#### 3.2 Setting break points for e1000 module load

In order to debug module during boot time, the debug target machine must use `kgdboc` and `kgdbwait` kernel boot options in grub.
Below is the example used on my debug target machine,

	console=ttyS0,9600 kgdboc=kbd,ttyS0 kgdbwait

After target machine got booted from grub, the kernel dropped into the `kdb` prompt immediately. It waited the debug instructions before boot.

On gdb client, we tried to connect to debug target by specifying remote IP and port,

	(gdb) target remote 127.0.0.1:2222
	Remote debugging using 127.0.0.1:2222
	kgdb_breakpoint () at kernel/debug/debug_core.c:1043
	1043 wmb(); /* Sync point after breakpoint */

After gdb got connected with target machine, used `break` to set the break point at `do_init_module`,

	(gdb) break do_init_module
	Breakpoint 1 at 0xffffffff810ed48d: file /usr/src/debug/kernel-3.10.0-327.el7/linux-3.10.0-327.el7.x86_64/arch/x86/include/asm/current.h, line 14.

The break point number for `do_init_module` is `1`, we used `command` to specify the gdb commands sequences while hitting the break point,

	(gdb) command 1
	Type commands for breakpoint(s) 1, one per line.
	End with a line saying just "end".
	>py if str(gdb.parse_and_eval("mod->name")).find("e1000") != 1: gdb.execute("continue", False, False)
	>end

	(gdb) c
	Continuing.

You may note that we didn't use the `strstr` to filter the module name.
In fact, gdb supports invoking a `strstr` function call at debug target, but it seemed kgdb couldn't support this feature as the gdb debug target.
I got below error messages while using `strstr` or `strlen` for kgdb debugging,

	Could not fetch register "st0"; remote failure reply 'E22'

For this reason, I had to use **GBD Python Exntension**, that could make sure the when module name in current context matches "e1000", it could stop to wait for manually debugging.
Otherwise, it would continue until the "e1000" got loaded. This trick really saves us lots of manually interaction works in gdb,

When kernel got stopped again, it was under the context of `do_init_module` for e1000 module,

	Breakpoint 1, load_module (info=info@entry=0xffff880036c83ef0, uargs=uargs@entry=0x7f430fc9ab99 "", flags=flags@entry=0) at kernel/module.c:3435
	3435 return do_init_module(mod);
	(gdb) p mod->name
	$4 = "e1000", '\000' <repeats 50 times>

#### 3.3 Load e1000 symbols manually

As we said in previous section, under this context, we should be able to get all ELF section name and address via `struct module` of e1000 module,

	(gdb) p mod
	$5 = (struct module *) 0xffffffffa00b9640
	(gdb) p mod->sect_attrs
	$7 = (struct module_sect_attrs *) 0xffff880036652800
	(gdb) p (struct module_sect_attrs *)mod->sect_attrs
	$8 = (struct module_sect_attrs *) 0xffff880036652800
	(gdb) p *(struct module_sect_attrs *)mod->sect_attrs
	$9 = {grp = {name = 0xffffffff8186ff16 "sections", is_visible = 0x0 <irq_stack_union>, attrs = 0xffff880036652dc8, bin_attrs = 0x0 <irq_stack_union>}, nsections = 20, attrs = 0xffff880036652828}

Per above output, we knew e1000 had 20 sections and the address of `struct module_sect_attr` array is `0xffff880036652828`.
Then we could dump all 20 elements in the array to get the section `name` and `address` by below command. Because the output is quite a lot, I didn't include them here,

	(gdb) p (*(struct module_sect_attr *)0xffff880036652828)@20

	[...snipped...]

After we got .text, .bss and .data section address, the `add-symbol-file` command could be used to load the e1000 module symbols,

	(gdb) add-symbol-file /usr/lib/debug/lib/modules/3.10.0-327.el7.x86_64/kernel/drivers/net/ethernet/intel/e1000/e1000.ko.debug 0xffffffffa009b000 -s .bss 0xffffffffa00b9878 -s .data 0xffffffffa00b7000
	add symbol table from file "/usr/lib/debug/lib/modules/3.10.0-327.el7.x86_64/kernel/drivers/net/ethernet/intel/e1000/e1000.ko.debug" at
	.text_addr = 0xffffffffa009b000
	.bss_addr = 0xffffffffa00b9878
	.data_addr = 0xffffffffa00b7000
	(y or n) y
	Reading symbols from /usr/lib/debug/usr/lib/modules/3.10.0-327.el7.x86_64/kernel/drivers/net/ethernet/intel/e1000/e1000.ko.debug...done.

Then we should be able to do e1000 module debug by using e1000 symbols directly. For example, setting the break points in `e1000_intr`.

Overall, the whole debug steps are quite complex and low efficiency. Do we have a better way to load e1000 symbol?

#### 3.4 Load e1000 symbols by gdb scripts

The efficient and easy way to load module symbols is using gdb scripts.

After kernel got stopped under the context of e1000 module load, we can invoke the gdb scripts to automate the module symbol load process.

	Breakpoint 1, load_module (info=info@entry=0xffff880036c83ef0, uargs=uargs@entry=0x7f430fc9ab99 "", flags=flags@entry=0) at kernel/module.c:3435
	3435 return do_init_module(mod);
	(gdb) p mod->name
	$4 = "e1000", '\000' <repeats 50 times>

The [getmod.py](https://github.com/teawater/kgtp/blob/master/getmod.py) is a light weight gdb python script to do the such kind of thing.
After invoked the tool, e1000 modules symbols got loaded automatically,

	(gdb) so ~/kgtp/getmod.py
	Use GDB command "set $mod_search_dir=dir" to set an directory for search the modules.
	0. /usr/lib/debug/usr/lib/modules/3.10.0-327.el7.x86_64
	1. /lib/modules/3.10.0-327.el7.x86_64
	Select a directory for search the modules [0]:
	add symbol table from file "/usr/lib/debug/usr/lib/modules/3.10.0-327.el7.x86_64/kernel/drivers/net/ethernet/intel/e1000/e1000.ko.debug" at
	.text_addr = 0xffffffffa009b000
	.note.gnu.build-id_addr = 0xffffffffa00b1000
	.text_addr = 0xffffffffa009b000
	.text.unlikely_addr = 0xffffffffa00afaec
	.init.text_addr = 0xffffffffa00c1000
	.exit.text_addr = 0xffffffffa00b0183
	.rodata_addr = 0xffffffffa00b1040
	.rodata.str1.1_addr = 0xffffffffa00b3400
	.rodata.str1.8_addr = 0xffffffffa00b4458
	.smp_locks_addr = 0xffffffffa00b6454
	__bug_table_addr = 0xffffffffa00b64f8
	.parainstructions_addr = 0xffffffffa00b6580
	__param_addr = 0xffffffffa00b6640
	__mcount_loc_addr = 0xffffffffa00b6820
	.data_addr = 0xffffffffa00b7000
	__verbose_addr = 0xffffffffa00b7988
	.data..read_mostly_addr = 0xffffffffa00b9620
	.gnu.linkonce.this_module_addr = 0xffffffffa00b9640
	.bss_addr = 0xffffffffa00b9878
	.symtab_addr = 0xffffffffa00c2000
	.strtab_addr = 0xffffffffa00c6740

The getmod.py is from [KGTP](https://github.com/teawater/kgtp) project, which provides kernel dynamic tracing functionalities for Linux kernel.
The script could be used individually without building and installing KGTP kernel modules.
Note that this tool is not only used for this early boot scenario, but also could be used for the module symbol loading after system boot.
Inside the scripts, it actually uses the similar approaches with our manually way in previous section to get module ELF section addresses.

In fact, in Linux v4.0, [the gdb scripts for kernel debugging got integrated](https://github.com/torvalds/linux/blob/master/Documentation/gdb-kernel-debugging.txt).
All gdb scripts are available under kernel mainline source tree: [scripts/gdb](https://github.com/torvalds/linux/tree/master/scripts/gdb).
Please follow the Linux Documentation here to understand how to use the scripts for kernel debugging.

Overall, gdb scripts are powerful and efficient for kernel debugging. However, they are tightly coupled with kernel, gdb implementations.
I won't be surprised that one gdb script got broken on a certain Linux kernel version or distribution.
For example, [getmod.py got some minor troubles on RHEL/CentOS kernel debugging](https://github.com/teawater/kgtp/commit/725bca2d473aaf991c48cf80a592bb85066ee252).
Some times, we have to fix this kind of scripts issue per kernel or Linux distributions differences by ourselves.

### 4. Related Readings

* [Using kdb/kgdb debug Linux kernel - 1](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-1/)
* [Using kdb/kgdb debug Linux kernel - 2](http://oliveryang.net/2015/08/using-kgdb-debug-linux-kernel-2/)
* [Debugging kernel and modules via gdb](https://github.com/torvalds/linux/blob/master/Documentation/gdb-kernel-debugging.txt)
* [My KGTP getmod.py patch for RHEL/CentOS/Fedora](https://github.com/teawater/kgtp/commit/725bca2d473aaf991c48cf80a592bb85066ee252)
* [8 gdb tricks you should know](https://blogs.oracle.com/ksplice/entry/8_gdb_tricks_you_should)
* [Linux Crash Utility - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash Utility - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
* [Debugger flow control: Hardware breakpoints vs software breakpoints - 1](http://www.nynaeve.net/?p=80)
* [Debugger flow control: Hardware breakpoints vs software breakpoints - 2](http://www.nynaeve.net/?p=81)
* [GDB Python API](https://sourceware.org/gdb/onlinedocs/gdb/Python-API.html)
* [x86-64 system V ABI](http://www.x86-64.org/documentation/abi.pdf)
