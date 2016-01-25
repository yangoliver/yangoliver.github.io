---
layout: post
title: Using kdb/kgdb debug Linux kernel - 1
categories:
- [English, Software]
tags:
- [kgdb, kernel, linux]
---

##Background

1. What is the kgdb?

	The kgdb is a kernel debugger. Similar with gdb for user application debug, kgdb is used for kernel debug.
	The debugger allows set break points in kernel code path, check kernel data structure, and control the kernel code running flow.
	
	The kgdb implementation got merged in Linux mainline since Linux 2.6.26.
	For major kgdb commit history in Linux community, please refer to <https://kgdb.wiki.kernel.org/index.php/Main_Page>.

2. What is the kdb? What are the differences between kdb and kgdb?

	The kdb, as known as "Built-in Kernel Debugger", is another Linux kernel debugger developed by [SGI](http://oss.sgi.com/projects/kdb/).
	However, it never got merged into Linux mainline before kgdb available in Linux kernel.
	
	In April 2009 KDB v4.4 had significant chunks of the code base removed and hooked it up to the same debug core and polled I/O drivers
	used by kgdb. In the other words, the kdb in Linux mainline is a front-end of kgdb now, but has less functionalities than its original
	kdb v4.4 implementation.
	
	The differences between kdb and kgdb from user point of view are,
	
	* kgdb requires two machines that are connected via a serial(or network) connection.
	  Whereas kdb can debug on the target machine directly.
	
	* kgdb debug client is gdb, which supports C source code level debugging, and also recognizes the kernel data structure.
	  Although kdb does not need a client, but it just supports assembly language level debugging, and cannot understand kernel data
	  structure. That means, kdb just can dump data structure as raw memory level.
	
	There is a [FAQ](https://kgdb.wiki.kernel.org/index.php/KDB_FAQ) to explain the differences between original kdb v4.4 and current kdb in
	Linux mainline.

3. What are the differences between crash and kdb/kgdb?

	The crash is a kernel post-mortem debug tool, but kdb/kgdb is in situ kernel debugger.
	Unlike gdb in user space, kdb/kgdb cannot be used to do kernel core dump analysis.

	My another [crash tool blog](https://oliveryang.net/2015/06/linux-crash-background/) has more information about this topic.

##HOWTO


1. How could we enable/disable kdb/kgdb?

	As kdb/kgdb are using same back-end, the enable/disable method are same. There are two methods,

	Before boot/reboot, in grub.cfg, boot kernel with arguments:

	<pre>console=ttyS0,115200 kgdboc=ttyS0,115200</pre>

	Or, configure kgdb over console under bash prompt, assuming you are using the keyboard and serial port console at same time:


	<pre># echo kbd,ttyS0 > /sys/module/kgdboc/parameters/kgdboc</pre>


2. How could we enter the kdb debug shell?

	If kdb/kgdb is enabled, there are 3 ways to drop into kdb debug shell,

	* While Linux kernel got panicked, kernel panic routine will calls into kgdb callback.
	* Under the bash prompt, using root to write to sysrq proc file,
		
	<pre># echo g > /proc/sysrq-trigger</pre>

	* Using hot key ***Magic Sysrq*** to enter the kdb debug shell immediately.

3. How to trigger ***Magic Sysrq*** on different environments?

	* Video console by keyboard

	  Press key combo ALT-SysRq-g. This is also works for VMware guest OS console.

	  Linux defined many other sysrq usage in kernel, please refer to
	  [Documentation/sysrq.txt](https://github.com/torvalds/linux/blob/master/Documentation/sysrq.txt)

	* Serial console

	  On serial console, there is no SysRq. It requires to trigger a "send break" to console.
	  Different terminal server supports different ways to "send break", for examples,


	  - For minicom 2.2
	
		  Press: Control-a
	
		  Press: f
	
		  Press: g
	
      - When you have telneted to a terminal server that supports sending a remote break
	
		  Press: Control-]
	
		  Type in:send break
	
		  Press: Enter
	
		  Press: g

	  - If you are using ```console``` command to connect the console server,
	  
	    Press: Ctrl-E-C-l-0-g

		Please refer to [console man page](http://www.conserver.com/docs/console.man.html) to understand how above key sequence work.

	  - For Virtualbox Guest OS, you can use ```VBoxManage controlvm``` command

	    With Virtualbox, the magic sysrq key sequence cannot be sent to guest since it is always interpreted by the host.
	    But the sysrq sequence can be sent using the management interface, e.g.

	   	<pre>VBoxManage controlvm [vbox-name] keyboardputscancode 1d 38 54 [request type press/release] d4 b8 9d</pre>

	    The request-type press/release hex code is the scancode of the sysrq code letter plus the scancode|0x80 for key release, e.g.

		<pre>g (kernel debugger): 22 a2</pre>

		22 is the letter g scancode, and a2 is scancode|0x80, so the kdb enter command is,

	    <pre>C:\Program Files\Oracle\VirtualBox>VBoxManage controlvm Ubuntu keyboardputscancode 1d 38 54 22 a2 d4 b8 9d</pre>

		See <http://www.win.tue.nl/~aeb/linux/kbd/scancodes-1.html> section 1.4 for complete list of scancodes.
		Caveat: The scancode depends on your keyboard layout, the codes here correspond to a standard layout.
