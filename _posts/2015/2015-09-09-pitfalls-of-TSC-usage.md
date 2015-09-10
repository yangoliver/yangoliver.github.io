---
layout: post
title: Pitfalls of TSC usage
categories:
- [English, OS, Hardware]
tags:
- [perf, kernel, linux, virtualization, hardware]
---

##Latency/Time measurement in user space

While user application developers are working on performance sensitive code, one common requirement is do latency/time
measurement in their code. This kind of code could be temporary code for debug/test/profiling purpose, or permanent
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
instruction (RDTSC). Following code are typical implementation for rdtsc() api,

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

However, in Linux kernel, it uses more complex way to get a better results,

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
		
	
##Known TSC pitfalls


TBD
