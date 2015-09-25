---
layout: post
title: Pitfalls of TSC usage
categories:
- [English, OS, Hardware]
tags:
- [perf, kernel, linux, virtualization, hardware]
---

## 1 Latency measurement in user space

While user application developers are working on performance sensitive code, one common requirement is do latency/time
measurement in their code. This kind of code could be temporary code for debug, test or profiling purpose, or permanent
code that could provide performance tracing data in software production mode.

Linux kernel provides gettimeofday() and clock_gettime() system calls for user application high resolution time measurement.
The gettimeofday() is us level, and clock_gettime is ns level. However, the major concerns of these system calls usage are
the additional performance cost caused by calling themselves.

In order to minimize the perf cost of gettimeofday() and clock_gettime() system calls, Linux kernel uses the
vsyscalls(virtual system calls) and VDSOs (Virtual Dynamically linked Shared Objects) mechanisms to avoid the cost
of switching from user to kernel. On x86, gettimeofday() and clock_gettime() could get better performance
due to vsyscalls [kernel patch](https://github.com/torvalds/linux/commit/2aae950b21e4bc789d1fc6668faf67e8748300b7),
by avoiding context switch from user to kernel space. But some other arch still need follow the regular
system call code path. This is really hardware dependent optimization.


## 2 Why using TSC?

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

	latency = cycle_2_ns(cycle)

In fact, above rdtsc implementation are problematic, and not encouraged by Linux kernel.
The major reason is, TSC mechanism is rather unreliable, and even Linux kernel had the hard time to handle it.

That is why Linux kernel does not provide the rdtsc api to user application. However, Linux kernel does not limit the
rdtsc instruction to be executed at privilege level, although x86 support the setup. That means, there is nothing stopping
Linux application read TSC directly by above implementation, but these applications have to prepare to handle some
strange TSC behaviors due to some known pitfalls.
	
## 3 Known TSC pitfalls

### 3.1 TSC unstable hardware

#### 3.1.1 CPU TSC capabilities

Intel CPUs have 3 sort of TSC behaviors,

* Variant TSC

The first generation of TSC, the TSC increments could be impacted by CPU frequency changes.
This is started from a very old processors (P4).

* Constant TSC

The TSC increments at a constant rate, even CPU frequency get changed. But the TSC could be stopped when CPU run into
deep C-state. Constant TSC is supported before Nehalem, and not as good as invariant TSC.

* Invariant TSC

The invariant TSC will run at a constant rate in all ACPI P-, C-, and T-states. This is the architectural behavior
moving forward. Invariant TSC only appears on Nehalem-and-later Intel processors.

See Intel 64 Architecture SDM Vol. 3A "17.12.1 Invariant TSC".

Linux defines several CPU feature bits per CPU differences,

* X86_FEATURE_TSC

The TSC is available in CPU.

* X86_FEATURE_CONSTANT_TSC

When CPU has a constant TSC.	

* X86_FEATURE_NONSTOP_TSC

When CPU does not stop for C-state.

The CONSTANT_TSC and NONSTOP_TSC flag combinations are enabled for invariant TSC.
Please refer to [this kernel patch](https://github.com/torvalds/linux/commit/40fb17152c50a69dc304dd632131c2f41281ce44)
for implementation.

If CPU has no "Invariant TSC" feature, it might cause the TSC problems, when kernel enables P or C state: as known as
turbo boost, speed-step, or CPU power management features.

For example, if NONSTOP_TSC feature is not detected by Linux kernel, when CPU ran into deep C-state for power saving,
[Intel idle driver](https://github.com/torvalds/linux/blame/master/drivers/idle/intel_idle.c)
will try to mark TSC with unstable flag,

	if (((mwait_cstate + 1) > 2) &&
		!boot_cpu_has(X86_FEATURE_NONSTOP_TSC))
		mark_tsc_unstable("TSC halts in idle"
				" states deeper than C2");

The ACPI CPU idle driver has the similar logic to check NONSTOP_TSC for deep C-state.

Please use below command on Linux to check CPU capabilities,

	$ cat  /proc/cpuinfo | grep -E "constant_tsc|nonstop_tsc"


* X86_FEATURE_TSC_RELIABLE

A synthetic flag, TSC sync checks are skipped.

CPU feature bits can only indicate the TSC stability in a UP system. For a SMP system, there are no explicit ways could be
used to ensure TSC reliability. The TSC sync test is the only way to test SMP TSC reliability.
However, some virtualization solution does provide good TSC sync mechanism. In order to handle some false
positive test results, VMware create a new synthetic
[TSC_RELIABLE feature bit](https://github.com/torvalds/linux/commit/b2bcc7b299f37037b4a78dc1538e5d6508ae8110)
in Linux kernel to bypass TSC sync testing. This flag is also used by other kernel components to bypass TSC sync
testing. Below command could be used to check this new synthetic CPU feature,

	$ cat  /proc/cpuinfo | grep "tsc_reliable"

If we could get the feature bit set on CPU, we should be able to trust the TSC source on this platform. But keep in
mind, software bugs in TSC handling still could cause the problems.

#### 3.1.2 TSC sync behaviors on SMP system

On a UP system, CPU TSC sync behavior among multiple cores is determined by CPU TSC capability. Whereas on a SMP system,
the TSC sync problem cross multiple CPU sockets could be a big problem. There are 3 type of SMP systems,

* No sync mechanism

On most older SMP and early multi-core machines, TSC was not synchronized between processors. Thus if an application
were to read the TSC on one processor, then was moved by the OS to another processor, then read TSC again, it might
appear that "time went backwards".

Both "Variant TSC" and "Constant TSC" CPUs on SMP machine have this problem.

* Sync among multiple CPU sockets on same main-board

After CPU supports "Invariant TSC", most recent SMP system could make sure TSC got synced among multiple CPUs. At boot
time, all CPUs connected with same RESET signal got reseted and TSCs are increased at same rate.

* No sync mechanism cross multiple cabinets, blades, or main-boards.

Depending on board and computer manufacturer design, different CPUs from different boards may connect to different
clock signal, which has no guarantee of TSC sync.

For example, on SGI UV systems, the TSC is not synchronized across blades. 
[A patch provided by SGI](https://github.com/torvalds/linux/commit/14be1f7454ea96ee614467a49cf018a1a383b189) tries to
disable TSC clock source for this kind of platform.

Even if a CPU has "Invariant TSC" feature, but the SMP system still can not provide reliable TSC.
For this reason, Linux kernel has to rely on some
[boot time or runtime testing](https://github.com/torvalds/linux/commit/95492e4646e5de8b43d9a7908d6177fb737b61f0)
instead of just detect CPU capabilities. The test sync test code used to have TSC value fix up code by calling write_tsc
code. Actually, Intel CPU provides a MSR register which allows software change the TSC value. This is how write_tsc
works. However, it is difficult to issue per CPU instructions over multiple CPUs to make TSC got a sync value. For this
reason, Linux kernel just check the tsc sync and will not to write to tsc now.

If TSC sync test passed during Linux kernel boot, following sysfs file would export tsc as current clock source,

	$ cat /sys/devices/system/clocksource/clocksource0/current_clocksource
	tsc


#### 3.1.3 Non-intel platform

Non-intel x86 platform has different stories. Current Linux kernel treats all non-intel SMP system as non-sync TSC system.
See unsynchronized_tsc code in [tsc.c](https://github.com/torvalds/linux/blob/master/arch/x86/kernel/tsc.c).
LKML also has the [AMD documents](https://lkml.org/lkml/2005/11/4/173).

#### 3.1.4 CPU hotplug

CPU hotplug will introduce a new CPU which may not have synchronized TSC values than existing CPUs. 
In theory, either system software, BIOS, or SMM code could do TSC sync for CPU hotplug.

In Linux kernel CPU hotplug code path, it will check tsc sync and may disable tsc clocksource by calling mark_tsc_unstable.
Linux kernel used to have TSC sync algorithm by using write_tsc call. But recent Linux code already removed the implementation
due to the sync code because there is no reliable software mechanism to make sure TSC values are exactly same by issuing multiple
instructions to multiple CPUs at exactly same time.

For this reason, per my understandings, Linux TSC sync on CPU hotplug scenario depends on hardware/firmware behaviors.


#### 3.1.5 Misc firmware problems

As TSC value is writeable, firmware code could change TSC value that caused TSC sync issue in OS.

There is [a LKML discussion](https://lwn.net/Articles/388286/) mentioned some BIOS SMI handler try to hide its execution
by changing TSC value.

Another example is related firmware behaviors in power management handling.As we mentioned earlier, CPU which has "Invariant TSC"
feature could avoid TSC rate changes during CPU deep C-state changes. However, some x86 firmware implementation change the
TSC value in its TSC sync implementation. In this case, TSC sync work from firmware, but could break from software perspective.
Linux kernel has to create
[a patch to handle ACPI suspend/resume](https://github.com/yangoliver/linux/commit/cd7240c0b900eb6d690ccee088a6c9b46dae815a)
to make sure TSC sync still works in OS.

#### 3.1.6 Misc hardware erratas

TSC sync functionality was highly depends on board manufacturer design. For example, clock source reliability issues.
I used to encountered a hardware errata caused by unreliable clock source. Due to the errata, Linux kernel TSC sync
test code
(check_tsc_sync_source in [tsc_sync.c](https://github.com/torvalds/linux/blob/master/arch/x86/kernel/tsc_sync.c))
reported error messages and disabled TSC as clock source.

[Another LKML discussion](https://lwn.net/Articles/388188/) also mentioned that SMP TSC drift in the clock signals
due to temperature problem. This finally could cause Linux detected the TSC wrap problems.

#### 3.1.7 Summary

TSC sync capability are not easy to be supported by x86 platform vendors. Under Linux, We can use following two steps to
check the platform capabilities,

* Check CPU capability flags

  For example, check /proc/cpuinfo under Linux or using cpuid instruction.
  Please refer to section 3.1.1. Note that VMware guest VM have a special flag.

* Check current kernel clock source

  Please refer to section 3.1.2.

User application who relies on TSC sync may do above two steps check to confirm whether TSC is reliable or not. However,
per the root causes of TSC problems, kernel may not able to test out all of unreliable cases. For example, it is still
possible that TSC clock had the problem during runtime. In this case, Linux may switch clock source from tsc to others
on the fly.

### 3.2 Software TSC usage bugs

#### 3.2.1 Overflow issues in TSC calculation

The direct return value of rdtsc is CPU cycle, but latency or time requires a regular time unit: ns or us.

In theory, 64bit TSC register is good enough for saving the CPU cycle, per Intel 64 Architecture SDM Vol. 3A 2-33,

<pre>The time-stamp counter is a model-specific 64-bit counter that is reset to zero each
time the processor is reset. If not reset, the counter will increment ~9.5 x 1016
times per year when the processor is operating at a clock rate of 3GHz. At this
clock frequency, it would take over 190 years for the counter to wrap around.</pre>

The overflow problem here is in implementations of cycle_2_ns or cycle_2_us, which need multiply cycle with
another big number, then this may cause the overflow problem.

Per current Linux implementation, when the overflow bug may happen if,

* The Linux OS has been running for more than 208 days
* The Linux OS reboot does not cause TSC reset due to kexec feature
* Some possible Hardware/Firmware bugs that cause no TSC reset during Linux OS reboot

Linux kernel used to get suffered from the overflow bugs
([patch for v3.2](https://github.com/torvalds/linux/commit/4cecf6d401a01d054afc1e5f605bcbfe553cb9b9)
 [patch for v3.4](https://github.com/torvalds/linux/commit/9993bc635d01a6ee7f6b833b4ee65ce7c06350b1))
when it try to use TSC to get a scheduler clock.

In order to avoid overflow bugs, cycle_2_ns in Linux kernel becomes more complex than we referred before,

	 * ns = cycles * cyc2ns_scale / SC
	 *
	 * Although we may still have enough bits to store the value of ns,
	 * in some cases, we may not have enough bits to store cycles * cyc2ns_scale,
	 * leading to an incorrect result.
	 *
	 * To avoid this, we can decompose 'cycles' into quotient and remainder
	 * of division by SC.  Then,
	 *
	 * ns = (quot * SC + rem) * cyc2ns_scale / SC
	 *    = quot * cyc2ns_scale + (rem * cyc2ns_scale) / SC
	 *
	 *			- sqazi@google.com

Unlike Linux kernel, some user applications uses below formula, which can cause the overflow if TSC cycles are more than
2 hours!

	ns = cycles * 10^6 / cpu_khz

Anyway, be careful for overflow issue when you use rdtsc value for a calculation.

#### 3.2.2 Wrong CPU frequency usage

You may already notice that, Linux kernel use CPU KHZ instead of GHZ/MHZ in its implementation. Please read
previous section about cycle_2_ns implementation.
The major reason of using KHZ here is: better precision. Old kernel code used MHZ before, and
[this patch](https://github.com/torvalds/linux/commit/dacb16b1a034fa7a0b868ee30758119fbfd90bc1) fixed the issue.

#### 3.2.3 Out of order execution

If the code you want to measure is a **very small** piece of code, our rdtsc function above might need to be
re-implement by LFENCE or RDTSCP. Otherwise, this will introduce the precision issues caused by CPU out of order execution.

See the description in Intel 64 Architecture SDM Vol. 2B,

<pre>The RDTSC instruction is not a serializing instruction. It does not necessarily wait
until all previous instructions have been executed before reading the counter. Similarly,
subsequent instructions may begin execution before the read operation is
performed. If software requires RDTSC to be executed only after all previous instructions
have completed locally, it can either use RDTSCP (if the processor supports that
instruction) or execute the sequence LFENCE;RDTSC.</pre>

Linux kernel has an example to have the
[rdtsc_ordered implementation](https://github.com/torvalds/linux/commit/03b9730b769fc4d87e40f6104f4c5b2e43889f19)

### 3.3 TSC emulation on different hypervisors

Virtualization technology caused the lots of challenges for guest OS time keeping. This section just cover the cases
that host could detect the TSC clock source, and guest software might be TSC sensitive and try to issue rdtsc instruction
to access TSC register while the task is running on a vCPU.

Comparing with physical problems, the virtualization introduced more challenges regarding to TSC sync.
For example, VM live migration may cause TSC sync problems if source and target hosts are different from hardware and software levels,

- Platform type differences (Intel vs AMD, reliable vs unreliable)
- CPU frequency (TSC increase rate)
- CPU boot time (TSC initial values)
- Hypervisor version differences

So the behaviors of TSC sync on different hypervisors could cause the TSC sync problems.

#### 3.3.1 Basic approaches

Per hypervisors differences, the rdtsc instruction and TSC sync could be addressed with following approaches,

1. Native or pass-through - fast but potentially incorrect

	No emulation by hypervisor. The instruction is directly executed on physical CPUs.
	This mode has faster performance but may cause the TSC sync problems to TSC sensitive applications in guest OS.

	Especially, VM could be live migrated to different machine. It is not possible and reasonable to ensure TSC value
	got synced among different machines.

2. Emulated or Trap - correct but slow

	- Full virtualization

	Hypervisor will emulate TSC, then rdtsc is not directly executed on physical CPUs.
	This mode causes performance degrade for rdtsc instruction, but give the reliability for TSC sensitive application.
	Intel and AMD CPUs support VMX and SVM which allows the hardware accelerations of rdtsc emulation.

	- Para virtualization

	In order to optimize the rdtsc performance, some hypervisor provided PVRDTSCP which allows software in VM could be
	paravirtualized (modified) for better performance. If user applications in VM directly issue the rdtsc instruction,
	the para virtualization solution can not work.

3. Hybrid - correct but potentially slow

	A hybrid algorithm to ensure correctness per following factors,

	- The requirement of correctness
	- Hardware TSC capabilities
	- Some special VM use case scenarios: VM is saved/restored/migrated

	When native run could get both good performance and correctness, it will be run natively without emulation.
	If hypervisor could not use native way, it will use full or para virtualization technology to make sure the correctness.

#### 3.3.2 Implementations on various hypervisors

Below is detailed information about the TSC support on various hypervisors,

1. VMware

	ESX 4.x and 3.x does not make TSC sync between vCPUs.
	But since ESX 5.x, the hypervisor always maintain the TSC got synced between vCPUs.
	VMware uses the hybrid algorithm to make sure TSC got synced even if underlaying hardware does not support TSC sync.
	For hardware with good TSC sync support, the rdtsc emulation could get good performance. But when hardware could not
	give TSC sync support, TSC emulation would be slower.

	However, VMware TSC emulation could not ensure there is no marginal TSC skew happen between CPUs. For this reason, Linux
	boot TSC sync check may fail.

	For this reason, in Linux guest, VMware creates a new synthetic TSC_RELIABLE feature bit to bypass Linux TSC sync testing.
	Linux [VMware cpu detect code] gives the good comments about TSC sync testing issues,

		/*
		 * VMware hypervisor takes care of exporting a reliable TSC to the guest.
		 * Still, due to timing difference when running on virtual cpus, the TSC can
		 * be marked as unstable in some cases. For example, the TSC sync check at
		 * bootup can fail due to a marginal offset between vcpus TSCs (though the
		 * TSCs do not drift from each other).  Also, the ACPI PM timer clocksource
		 * is not suitable as a watchdog when running on a hypervisor because the
		 * kernel may miss a wrap of the counter if the vcpu is descheduled for a
		 * long time. To skip these checks at runtime we set these capability bits,
		 * so that the kernel could just trust the hypervisor with providing a
		 * reliable virtual TSC that is suitable for timekeeping.
		 */
		static void vmware_set_cpu_features(struct cpuinfo_x86 *c)
		{
			set_cpu_cap(c, X86_FEATURE_CONSTANT_TSC);
			set_cpu_cap(c, X86_FEATURE_TSC_RELIABLE);
		}

	The [patch](https://github.com/torvalds/linux/commit/eca0cd028bdf0f6aaceb0d023e9c7501079a7dda) got merged in Linux 2.6.29.

	VMware also provides
	[Timekeeping in VMware Virtual Machines](http://www.vmware.com/files/pdf/Timekeeping-In-VirtualMachines.pdf) to discuss
	TSC emulation issues. Please refer to this document for detailed information.

2. Hyper-V

	Hyper-V does not provide TSC emulation. For this reason, TSC on hyper-V is not reliable. But the problem is, hyper-V
	Linux CPU driver never reported the problem, that means the TSC clock source is still could be used if it happed to
	pass Linux kernel TSC sync test.
	Just 20 Days ago, a Linux kernel
	[4.3-rc1 patch](https://github.com/torvalds/linux/commit/88c9281a9fba67636ab26c1fd6afbc78a632374f)
	had disabled the TSC clock source on Hyper-V Linux guest.

3. KVM

	On the latest Linux guest OS, KVM uses kvmclock driver by default.

	* Try for perfect synchronization where possible
	* Use TSC stabilization techniques
	* No frequency compensation
	* No TSC trapping, user space rdtsc is imperfect
	* Map pvclock and run kvmclock from VDSO/vsyscalls for gettimeofday()

	The drawbacks of kvmclock is that user space TSC read will still have the problem. Because user space rdtsc could not
	be fixed by kvmclock and the only way to fix it is TSC emulation/trap.

	For the legacy OS with kvmclock driver, KVM guest seemed to run rdtsc natively without emulation.

	However, I did not see KVM code has supported TSC trap here. The 
	I just found [an old kernel patch to support TSC trap](https://lkml.org/lkml/2011/1/6/90).
	But I have not found that it got merged into Linux mainline.

	For above reasons, I think a rdtsc sensitive application running over KVM Linux guest would be problematic.
	KVM actually has
	[a kernel documentation](https://github.com/yangoliver/linux/blob/master/Documentation/virtual/kvm/timekeeping.txt)
	about the timekeeping, but the document does not have enough information about KVM implementation.

4. Xen

	Prior to Xen 4.0, it only support native mode.
	Xen 4.0 provides tsc_mode parameter, which allows administrators switch between 4 modes per their requirements.
	By default Xen 4.0 use the hybrid mode. [This Xen document](http://xenbits.xen.org/docs/4.2-testing/misc/tscmode.txt)
	gives very detailed discussion about TSC emulation.

#### 3.3.3 Summary

VMware and Xen seems provide best solution for TSC sync. The KVM PV emulation never addresses user space rdtsc
use case problems. And hyper-V has no TSC sync solution. All these TSC sync solutions just provide the way that let Linux
kernel TSC clocksource continuously work. The tiny TSC skew may still be observed in VM although TSC sync is supported by
some hypervisors. Thus application may still have a wrong TSC duration for time measurement.

## 4 Conclusion

Linux kernel could detect TSC sync problem and try to be "TSC-resilient". The major problem is in user application.
There is no reliable TSC sync mechanism for user application especially under a Virtualization environment.
Here are the suggestions,

1. If possible, avoid to use rdtsc in user applications.

   Not all of hardware, hypervisors are TSC safe, which means TSC may behave incorrectly.

   TSC usage will cause software porting bugs cross various x86 platforms or different hypervisors.
   Leverage syscall or vsyscall will make software portable, especially for Virtualization environment.

2. If you have to use it, please make your application "TSC-resilient".

   Use it for debugging, but never use rdtsc in functional area.
   
   As we mentioned above, Linux kernel also had hard time to handle it until today. If possible, learn from Linux code first.
   Perf measurement and debug facility might be only usable cases, but be prepare for handling various conner cases
   and software porting problems.

   Understand the risks from hardware, OS kernel, hypervisors. Write a "TSC-resilient" application, which make sure your
   application still can behave correctly when TSC value is wrong.
