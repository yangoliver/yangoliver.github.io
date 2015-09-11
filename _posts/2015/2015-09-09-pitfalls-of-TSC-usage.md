---
layout: post
title: Pitfalls of TSC usage
categories:
- [English, OS, Hardware]
tags:
- [perf, kernel, linux, virtualization, hardware]
---

##Latency measurement in user space

While user application developers are working on performance sensitive code, one common requirement is do latency/time
measurement in their code. This kind of code could be temporary code for debug, test or profiling purpose, or permanent
code that could provide performance tracing data in software production mode.

Linux kernel provides gettimeofday() and clock_gettime() system calls for user application high resolution time measurement.
The gettimeofday() is us level, and clock_gettime is ns level. However, the major concerns of these system calls usage are
the additional performance cost caused by calling themselves.

In order to minimize the perf cost of gettimeofday() and clock_gettime() system calls, Linux kernel uses the
vsyscalls(virtual system calls) and VDSOs (Virtual Dynamically linked Shared Objects) mechanisms to avoid the cost
of switching from user to kernel. On x86, gettimeofday() and clock_gettime() could get better performance due to
vsyscalls, by avoiding context switch from user to kernel space. But some other arch still need follow the regular
system call code path. This is really hardware dependent optimization.

##Why using TSC?

Although vsyscalls implementation of gettimeofday() and clock_gettime() is faster than regular system calls, the perf cost
of them is still too high to meet the latency measurement requirements for some perf sensitive application.

The TSC (time stamp counter) provided by x86 processors is a high-resolution counter that can be read with a single
instruction (RDTSC). On Linux this instruction could be executed from user space directly, that means user applications could
use one single instruction to get a fine-grained timestamp (nanosecond level) with a much faster way than vsyscalls.

Following code are typical implementation for rdtsc() api in user space application,

	static uint64_t rdtsc(void)
	{
		uint64_t var;
		uint32_t hi, lo;
	
		__asm volatile
		    ("rdtsc" : "=a" (lo), "=d" (hi));
	
		var = ((uint64_t)hi << 32) | lo;
		return (var);
	}

The result of rdtsc is CPU cycle, that could be converted to nanoseconds by a simple calculation.

<pre>ns = CPU cycles * (ns_per_sec / CPU freq)</pre>

In Linux kernel, it uses more complex way to get a better results,

	/*
	 * Accelerators for sched_clock()
	 * convert from cycles(64bits) => nanoseconds (64bits)
	 *  basic equation:
	 *              ns = cycles / (freq / ns_per_sec)
	 *              ns = cycles * (ns_per_sec / freq)
	 *              ns = cycles * (10^9 / (cpu_khz * 10^3))
	 *              ns = cycles * (10^6 / cpu_khz)
	 *
	 *      Then we use scaling math (suggested by george@mvista.com) to get:
	 *              ns = cycles * (10^6 * SC / cpu_khz) / SC
	 *              ns = cycles * cyc2ns_scale / SC
	 *
	 *      And since SC is a constant power of two, we can convert the div
	 *  into a shift.
	 *
	 *  We can use khz divisor instead of mhz to keep a better precision, since
	 *  cyc2ns_scale is limited to 10^6 * 2^10, which fits in 32 bits.
	 *  (mathieu.desnoyers@polymtl.ca)
	 *
	 *                      -johnstul@us.ibm.com "math is hard, lets go shopping!"
	 */


Finally, the code of latency measurement could be,
	
	start = rdtsc();

	/* put code you want to measure here */

	end = rdtsc();

	cycle = end - start;

	latency = cycle_to_ns(cycle)

In fact, above rdtsc implementation are problematic, and not encouraged by Linux kernel.
The major reason is, TSC mechanism is rather unreliable, and even Linux kernel had the hard time to handle it.

That is why Linux kernel does not provide the rdtsc api to user application. However, Linux kernel does not limit the
rdtsc instruction to be excuted at privilege level, although x86 support the setup. That means, there is nothing stopping
Linux application read TSC directly by above implementation, but these applications have to prepare to handle some
strange TSC behaviors due to some known pitfalls.
	
##Known TSC pitfalls

###Hardware

1. TSC increments differently on different Intel processors

	Intel CPUs have 3 sort of TSC behaviors,

	* Invariant TSC

	The invariant TSC will run at a constant rate in all ACPI P-, C-. and T-states. This is the architectural behavior
	moving forward. Invariant TSC only appears on Nehalem-and-later Intel processors.

	See Intel 64 Architecture SDM Vol. 3A "17.12.1 Invariant TSC".

	* Constant TSC

    The TSC increments at a constant rate, even CPU frequency get changed. But the TSC could be stopped when CPU run into
	deep C-state. Constant TSC is supported before Nehalem, and not as good as invariant TSC.

    * Variant TSC

    The first generation of TSC, the TSC increments could be impacted by CPU frequency changes.
	This is started from a very old processors (P4).


	Linux kernel defined cpu feature flag CONSTANT_TSC for Constant TSC and "CONSTANT_STC | NONSTOP_TSC" for Invariant TSC.
	Please refer to below kernel patch,

	https://github.com/torvalds/linux/commit/40fb17152c50a69dc304dd632131c2f41281ce44

	If CPU has no "Invariant TSC" feature, it might cause the TSC problems, when kernel enables P or C state: as known as
	turbo boost, speedstep, or CPU power management features.

2. TSC sync behavior differences on Intel SMP system

	* No sync mechanism

    On most older SMP and early multi-core machines, TSC was not synchronized between processors. Thus if an application
	were to read the TSC on one processor, then was moved by the OS to another processor, then read TSC again, it might
	appear that "time went backwards". 

	Both "Variant TSC" and "Constant TSC" CPUs on SMP machine have this problem.

	* Sync among multiple CPU sockets on same mainboard

	After CPU supports "Invariant TSC", most recent SMP system could make sure TSC got synced among multiple CPUs. At boot
	time, all CPUs connected with same RESET signal got reseted and TSCs are increased at same rate.

	* No sync mechanism cross multiple cabinets, blades, or mainboards.

	Depending on board and computer manufacturer design, different CPUs from different boards may connect to different
	clock signal, which has no guarantee of TSC sync.

	For exmaple, on SGI UV systems, the TSC is not synchronized across blades. Below patch provided by SGI tries to disable
	TSC 

	https://github.com/torvalds/linux/commit/14be1f7454ea96ee614467a49cf018a1a383b189


	Linux kernel has to rely on some runtime checking and testing instead of just detect CPU capabilities.
	For this reason, even CPUs have "Invariant TSC" feature, but the SMP system still can not provide reliable TSC.

3. Non-intel x86 SMP platform

	Non-intel platform has differnt stories. Current Linux kernel treats all non-intel SMP system as non-sync TSC system.

	See unsynchronized_tsc code in Linux 4.0. LKML also has the [AMD documents](https://lkml.org/lkml/2005/11/4/173).

4. Misc hardware erratas and problems

	TSC sync functionality was highly depends on board manufacturer design. I used to encountered a server vendor
	hardware bugs that caused Intel CPU get out of sync even the system should support TSC sync.

	Also some LKML discussions gives an example about SMP TSC drift in the clock signals due to temperature problem.


###Software

1. Precision issues caused by out of order problem

	If the code you want to measure is a **very small** piece of code, our rdtsc function above might need to be
	re-implement by LFENCE or RDTSCP.

	See the description in Intel 64 Architecture SDM Vol. 2B,

	<pre> The RDTSC instruction is not a serializing instruction. It does not necessarily wait
	until all previous instructions have been executed before reading the counter. Similarly,
	subsequent instructions may begin execution before the read operation is
	performed. If software requires RDTSC to be executed only after all previous instructions
	have completed locally, it can either use RDTSCP (if the processor supports that
	instruction) or execute the sequence LFENCE;RDTSC.</pre>

2. overflow bugs in cycle2ns or cycle2us

	TBD.

3. TSC support on different hypervisors

	TBD.
