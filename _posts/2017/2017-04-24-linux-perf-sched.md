---
layout: post
title: Linux perf sched Summary
description: Brendan Gregg perf sched for Linux CPU scheduler analysis 中译版
categories: [Chinese, Software]
tags: [perf, kernel, linux]
---

>本文翻译自 Brendan Gregg 博客文章，所有权利归原作者所有

>原文链接 http://www.brendangregg.com/blog/2017-03-16/perf-sched.html


* content
{:toc}

## 1. Overview ##

随着 Linux 4.10 `perf sched timehist` 新特性的推出，Linux 的 perf 工具又增加了一个新的 CPU 调度器性能分析的方式。因为我之前从未谈到过 `perf sched` 这个子命令，本文将对其功能做一个总结。
对急于了解本文是否对自己有用的同学，可以先大致浏览一下本文中的命令输出截屏。这些 `perf sched` 命令的例子也被加入到之前维护的
[perf exmaples](http://www.brendangregg.com/perf.html#SchedulerAnalysis) 页面里。

`perf sched` 使用了转储后再分析 (dump-and-post-process) 的方式来分析内核调度器的各种事件。而这往往带来一些问题，因为这些调度事件通常非常地频繁，可以达到每秒钟百万级，
进而导致 CPU，内存和磁盘的在调度器事件记录上的严重开销。我最近一直在用 [eBPF/bcc](https://github.com/iovisor/bcc) (包括 [runqlat](http://www.brendangregg.com/blog/2016-10-08/linux-bcc-runqlat.html))
来写内核调度器分析工具，使用 eBPF 特性在内核里直接对调度事件的分析处理，可以极大的减少这种事件记录的开销。但是有一些性能分析场景里，我们可能想用 `perf shed` 命令去记录每一个调度事件，
尽管比起 ebpf 的方式，这会带来更大的开销。想象一下这个场景，你有只有五分钟时间去分析一个有问题的云的虚拟机实例，在这个实例自动销毁之前，你想要为日后的各种分析去记录每个调度事件。

我们以记录一秒钟内的所有调度事件作为开始：

	# perf sched record -- sleep 1
	[ perf record: Woken up 1 times to write data ]
	[ perf record: Captured and wrote 1.886 MB perf.data (13502 samples) ]

这个命令的结果是一秒钟记录了 1.9 Mb 的数据，其中包含了 13,502 个调度事件样本。数据的大小和速度和系统的工作负载以及 CPU 数目的多少直接相关 (本例中正在一个 8 CPU 的服务器上 build 一个软件)。
事件记录如何被写入文件系统的过程已经被优化过了：为减少记录开销，perf 命令仅仅被唤醒一次，去读事件缓冲区里的数据，然后写到磁盘上。因此这种方式下，仍旧会有非常显著的开销，
包括调度器事件的产生和文件系统的数据写入。

这些调度器事件包括，

	# perf script --header
	# ========
	# captured on: Sun Feb 26 19:40:00 2017
	# hostname : bgregg-xenial
	# os release : 4.10-virtual
	# perf version : 4.10
	# arch : x86_64
	# nrcpus online : 8
	# nrcpus avail : 8
	# cpudesc : Intel(R) Xeon(R) CPU E5-2680 v2 @ 2.80GHz
	# cpuid : GenuineIntel,6,62,4
	# total memory : 15401700 kB
	# cmdline : /usr/bin/perf sched record -- sleep 1 
	# event : name = sched:sched_switch, , id = { 2752, 2753, 2754, 2755, 2756, 2757, 2758, 2759...
	# event : name = sched:sched_stat_wait, , id = { 2760, 2761, 2762, 2763, 2764, 2765, 2766, 2...
	# event : name = sched:sched_stat_sleep, , id = { 2768, 2769, 2770, 2771, 2772, 2773, 2774, ...
	# event : name = sched:sched_stat_iowait, , id = { 2776, 2777, 2778, 2779, 2780, 2781, 2782,...
	# event : name = sched:sched_stat_runtime, , id = { 2784, 2785, 2786, 2787, 2788, 2789, 2790...
	# event : name = sched:sched_process_fork, , id = { 2792, 2793, 2794, 2795, 2796, 2797, 2798...
	# event : name = sched:sched_wakeup, , id = { 2800, 2801, 2802, 2803, 2804, 2805, 2806, 2807...
	# event : name = sched:sched_wakeup_new, , id = { 2808, 2809, 2810, 2811, 2812, 2813, 2814, ...
	# event : name = sched:sched_migrate_task, , id = { 2816, 2817, 2818, 2819, 2820, 2821, 2822...
	# HEADER_CPU_TOPOLOGY info available, use -I to display
	# HEADER_NUMA_TOPOLOGY info available, use -I to display
	# pmu mappings: breakpoint = 5, power = 7, software = 1, tracepoint = 2, msr = 6
	# HEADER_CACHE info available, use -I to display
	# missing features: HEADER_BRANCH_STACK HEADER_GROUP_DESC HEADER_AUXTRACE HEADER_STAT 
	# ========
	#
	    perf 16984 [005] 991962.879966:   sched:sched_wakeup: comm=perf pid=16999 prio=120 target_cpu=005
		[...]

`perf sched` 可以用几种不同的方式记录调度事件，其 help 子命令总结如下:

	# perf sched -h

	 Usage: perf sched [] {record|latency|map|replay|script|timehist}

	    -D, --dump-raw-trace  dump raw trace in ASCII
	    -f, --force           don't complain, do it
	    -i, --input     input file name
	    -v, --verbose         be more verbose (show symbol address, etc)

## 2. perf sched latency ##

其中，`perf sched latency` 可以给出每个任务 (task) 的调度延迟，包括平均和最大延迟:

	# perf sched latency
	
	 -----------------------------------------------------------------------------------------------------------------
	  Task                  |   Runtime ms  | Switches | Average delay ms | Maximum delay ms | Maximum delay at       |
	 -----------------------------------------------------------------------------------------------------------------
	  cat:(6)               |     12.002 ms |        6 | avg:   17.541 ms | max:   29.702 ms | max at: 991962.948070 s
	  ar:17043              |      3.191 ms |        1 | avg:   13.638 ms | max:   13.638 ms | max at: 991963.048070 s
	  rm:(10)               |     20.955 ms |       10 | avg:   11.212 ms | max:   19.598 ms | max at: 991963.404069 s
	  objdump:(6)           |     35.870 ms |        8 | avg:   10.969 ms | max:   16.509 ms | max at: 991963.424443 s
	  :17008:17008          |    462.213 ms |       50 | avg:   10.464 ms | max:   35.999 ms | max at: 991963.120069 s
	  grep:(7)              |     21.655 ms |       11 | avg:    9.465 ms | max:   24.502 ms | max at: 991963.464082 s
	  fixdep:(6)            |     81.066 ms |        8 | avg:    9.023 ms | max:   19.521 ms | max at: 991963.120068 s
	  mv:(10)               |     30.249 ms |       14 | avg:    8.380 ms | max:   21.688 ms | max at: 991963.200073 s
	  ld:(3)                |     14.353 ms |        6 | avg:    7.376 ms | max:   15.498 ms | max at: 991963.452070 s
	  recordmcount:(7)      |     14.629 ms |        9 | avg:    7.155 ms | max:   18.964 ms | max at: 991963.292100 s
	  svstat:17067          |      1.862 ms |        1 | avg:    6.142 ms | max:    6.142 ms | max at: 991963.280069 s
	  cc1:(21)              |   6013.457 ms |     1138 | avg:    5.305 ms | max:   44.001 ms | max at: 991963.436070 s
	  gcc:(18)              |     43.596 ms |       40 | avg:    3.905 ms | max:   26.994 ms | max at: 991963.380069 s
	  ps:17073              |     27.158 ms |        4 | avg:    3.751 ms | max:    8.000 ms | max at: 991963.332070 s
	...]

为说明这些调度事件是如何记录和计算的，这里会以上面一行，最大调度延迟 29.702 毫秒的例子来说明。同样的结果，可以使用 `perf sched script` 展现其原始调度事件:

	sh 17028 [001] 991962.918368:  sched:sched_wakeup_new: comm=sh pid=17030 prio=120 target_cpu=002
	[...]
	cc1 16819 [002] 991962.948070: sched:sched_switch: prev_comm=cc1 prev_pid=16819 prev_prio=120
                                                       prev_state=R ==> next_comm=sh next_pid=17030 next_prio=120
	[...]

从 `sh` 任务被唤醒时间点 (991962.918368 单位是秒) 到 `sh` 通过上下文切换即将被执行的时间点 (991962.948070) 的时间间隔是 29.702 毫秒。原始调度事件列出的 `sh` (shell) 进程， 很快就会执行 `cat` 命令，
因此在 `perf sched latency` 输出里显示的是 cat 命令的调度延迟。

## 3. perf sched map ##

`perf sched map` 显示所有的 CPU 的上下文切换的事件，其中的列输出了每个 CPU 正在做什么，以及具体时间。它和我们在内核调度器分析 GUI 软件看到的可视化数据 (包括 `perf timechart` 的输出做 90 度旋转后）
都是一样的。下面是一个输出的例子：

	# perf sched map
	                      *A0           991962.879971 secs A0 => perf:16999
	                       A0     *B0   991962.880070 secs B0 => cc1:16863
	          *C0          A0      B0   991962.880070 secs C0 => :17023:17023
	  *D0      C0          A0      B0   991962.880078 secs D0 => ksoftirqd/0:6
	   D0      C0 *E0      A0      B0   991962.880081 secs E0 => ksoftirqd/3:28
	   D0      C0 *F0      A0      B0   991962.880093 secs F0 => :17022:17022
	  *G0      C0  F0      A0      B0   991962.880108 secs G0 => :17016:17016
	   G0      C0  F0     *H0      B0   991962.880256 secs H0 => migration/5:39
	   G0      C0  F0     *I0      B0   991962.880276 secs I0 => perf:16984
	   G0      C0  F0     *J0      B0   991962.880687 secs J0 => cc1:16996
	   G0      C0 *K0      J0      B0   991962.881839 secs K0 => cc1:16945
	   G0      C0  K0      J0 *L0  B0   991962.881841 secs L0 => :17020:17020
	   G0      C0  K0      J0 *M0  B0   991962.882289 secs M0 => make:16637
	   G0      C0  K0      J0 *N0  B0   991962.883102 secs N0 => make:16545
	   G0     *O0  K0      J0  N0  B0   991962.883880 secs O0 => cc1:16819
	   G0 *A0  O0  K0      J0  N0  B0   991962.884069 secs 
	   G0  A0  O0  K0 *P0  J0  N0  B0   991962.884076 secs P0 => rcu_sched:7
	   G0  A0  O0  K0 *Q0  J0  N0  B0   991962.884084 secs Q0 => cc1:16831
	   G0  A0  O0  K0  Q0  J0 *R0  B0   991962.884843 secs R0 => cc1:16825
	   G0 *S0  O0  K0  Q0  J0  R0  B0   991962.885636 secs S0 => cc1:16900
	   G0  S0  O0 *T0  Q0  J0  R0  B0   991962.886893 secs T0 => :17014:17014
	   G0  S0  O0 *K0  Q0  J0  R0  B0   991962.886917 secs 
	[...]

这是一个 8 CPU 系统，你可以看到从左到右 8 个列的输出来代表每个 CPU。一些 CPU 的列以空白开始，因为在我们开始运行命令分析系统时，刚开始记录调度事件。很快地，各个 CPU 所在列就开始填满输出了。

输出中的两个字符的代码 ("A0" "C0")，时用于区分识别各个任务的，其关联的任务的名字显示在右侧 ("=>")。“*” 字符表示这个 CPU 上当时有上下文切换事件，从而导致新的调度事件发生。
例如，上面输出的最后一行表示在 991962.886917 秒的时间点， CPU 4 上发生了上下文切换，导致了任务 K0 的执行 (“cc1" 进程，PID 是 16945)。

上面这个例子来自一个繁忙的系统，下面是一个空闲系统的例子：

	# perf sched map
	                      *A0           993552.887633 secs A0 => perf:26596
	  *.                   A0           993552.887781 secs .  => swapper:0
	   .                  *B0           993552.887843 secs B0 => migration/5:39
	   .                  *.            993552.887858 secs 
	   .                   .  *A0       993552.887861 secs 
	   .                  *C0  A0       993552.887903 secs C0 => bash:26622
	   .                  *.   A0       993552.888020 secs 
	   .          *D0      .   A0       993552.888074 secs D0 => rcu_sched:7
	   .          *.       .   A0       993552.888082 secs 
	   .           .      *C0  A0       993552.888143 secs 
	   .      *.   .       C0  A0       993552.888173 secs 
	   .       .   .      *B0  A0       993552.888439 secs 
	   .       .   .      *.   A0       993552.888454 secs 
	   .      *C0  .       .   A0       993552.888457 secs 
	   .       C0  .       .  *.        993552.889257 secs 
	   .      *.   .       .   .        993552.889764 secs 
	   .       .  *E0      .   .        993552.889767 secs E0 => bash:7902
	...]

输出中，空闲 CPU 被显示为 "."。

注意检查输出中的时间戳所在的列，这对数据的可视化很有意义 (GUI 的调度器分析工具使用时间戳作为一个维度，这样非常易于理解，但是 CLI 的工具只列出了时间戳的值)。这个输出里也只显示了上下文切换事件的情况，
而没有包含调度延迟。新子命令 `timehist` 有一个可视化 (-V) 选项，允许包含唤醒 (wakeup) 事件。

## 4. perf sched timehist ##

`perf sched timehist` 是 Linux 4.10 里加入的，可以按照调度事件表示调度延迟，其中包括了任务等待被唤醒的时间 (wait time) 和任务从被唤醒之后到运行态的调度延迟。其中的调度延迟是我们更感兴趣去优化的。
详见下例：

	# perf sched timehist
	Samples do not have callchains.
	           time    cpu  task name                       wait time  sch delay   run time
	                        [tid/pid]                          (msec)     (msec)     (msec)
	--------------- ------  ------------------------------  ---------  ---------  ---------
	  991962.879971 [0005]  perf[16984]                         0.000      0.000      0.000 
	  991962.880070 [0007]  :17008[17008]                       0.000      0.000      0.000 
	  991962.880070 [0002]  cc1[16880]                          0.000      0.000      0.000 
	  991962.880078 [0000]  cc1[16881]                          0.000      0.000      0.000 
	  991962.880081 [0003]  cc1[16945]                          0.000      0.000      0.000 
	  991962.880093 [0003]  ksoftirqd/3[28]                     0.000      0.007      0.012 
	  991962.880108 [0000]  ksoftirqd/0[6]                      0.000      0.007      0.030 
	  991962.880256 [0005]  perf[16999]                         0.000      0.005      0.285 
	  991962.880276 [0005]  migration/5[39]                     0.000      0.007      0.019 
	  991962.880687 [0005]  perf[16984]                         0.304      0.000      0.411 
	  991962.881839 [0003]  cat[17022]                          0.000      0.000      1.746 
	  991962.881841 [0006]  cc1[16825]                          0.000      0.000      0.000 
	[...]
	  991963.885740 [0001]  :17008[17008]                      25.613      0.000      0.057 
	  991963.886009 [0001]  sleep[16999]                     1000.104      0.006      0.269 
	  991963.886018 [0005]  cc1[17083]                         19.998      0.000      9.948 

上面的输出包含了前面 `perf record` 运行时，为设定跟踪时间为 1 秒钟而执行的 sleep 命令。你可以注意到，sleep 命令的等待时间是 10000.104 毫秒，这是该命令等待被定时器唤醒的时间。
这个 sleep 命令的调度延迟只有 0.006 毫秒，并且它在 CPU 上真正运行的时间只有 0.269 毫秒。

`timehist` 子命令有很多命令选项，包括 -V 选项用以增加 CPU 可视化列输出，-M 选项用以增加调度迁移事件，和 -w 选项用以显示唤醒事件。例如：

	# perf sched timehist -MVw
	Samples do not have callchains.
	           time    cpu  012345678  task name           wait time  sch delay   run time
	                                   [tid/pid]              (msec)     (msec)     (msec)
	--------------- ------  ---------  ------------------  ---------  ---------  ---------
	  991962.879966 [0005]             perf[16984]                                          awakened: perf[16999]
	  991962.879971 [0005]       s     perf[16984]             0.000      0.000      0.000
	  991962.880070 [0007]         s   :17008[17008]           0.000      0.000      0.000
	  991962.880070 [0002]    s        cc1[16880]              0.000      0.000      0.000
	  991962.880071 [0000]             cc1[16881]                                           awakened: ksoftirqd/0[6]
	  991962.880073 [0003]             cc1[16945]                                           awakened: ksoftirqd/3[28]
	  991962.880078 [0000]  s          cc1[16881]              0.000      0.000      0.000
	  991962.880081 [0003]     s       cc1[16945]              0.000      0.000      0.000
	  991962.880093 [0003]     s       ksoftirqd/3[28]         0.000      0.007      0.012
	  991962.880108 [0000]  s          ksoftirqd/0[6]          0.000      0.007      0.030
	  991962.880249 [0005]             perf[16999]                                          awakened: migration/5[39]
	  991962.880256 [0005]       s     perf[16999]             0.000      0.005      0.285
	  991962.880264 [0005]        m      migration/5[39]                                      migrated: perf[16999] cpu 5 => 1
	  991962.880276 [0005]       s     migration/5[39]         0.000      0.007      0.019
	  991962.880682 [0005]        m      perf[16984]                                          migrated: cc1[16996] cpu 0 => 5
	  991962.880687 [0005]       s     perf[16984]             0.304      0.000      0.411
	  991962.881834 [0003]             cat[17022]                                           awakened: :17020
	...]
	  991963.885734 [0001]             :17008[17008]                                        awakened: sleep[16999]
	  991963.885740 [0001]   s         :17008[17008]          25.613      0.000      0.057
	  991963.886005 [0001]             sleep[16999]                                         awakened: perf[16984]
	  991963.886009 [0001]   s         sleep[16999]         1000.104      0.006      0.269
	  991963.886018 [0005]       s     cc1[17083]             19.998      0.000      9.948 # perf sched timehist -MVw

CPU 可视化列 ("012345678") 用于表示对应 CPU 的调度事件。如果包含一个 "s" 字符，就表示上下文切换事件的发生，但如果是 "m" 字符，就代表调度迁移事件发生。

以上输出的最后几个事件里包含了之前 `perf record` 里设定时间的 sleep 命令。其中唤醒发生在时间点 991963.885734，并且在时间点 991963.885740 (6 微妙之后)，CPU 1 开始发生上下文切换，sleep 命令被调度执行。
其中任务名所在的列仍然显示 ":17008[17008]"，以代表上下文切换开始前在 CPU 上的进程，但是上下文切换完成后被调度的目标进程并没有显示，它实际上可以在原始调度事件 (raw events) 里可以被找到：

	:17008 17008 [001] 991963.885740:       sched:sched_switch: prev_comm=cc1 prev_pid=17008 prev_prio=120
	                                                             prev_state=R ==> next_comm=sleep next_pid=16999 next_prio=120

时间戳为 991963.886005 的事件表示了 sleep 进程在 CPU 上运行时，perf 命令收到了一个唤醒 (这应该是 sleep 命令在结束退出时唤醒了它的父进程)。随后在时间点 991963.886009，上下文切换事件发生，
这时 sleep 命令停止执行，并且打印出上下文切换事件的跟踪记录：在 sleep 运行期间，它有 1000.104 毫秒的等待时间，0.006 毫秒的调度延迟，和 0.269 毫秒的 CPU 实际运行时间。

下面对 `timehist` 的输出做了上下文切换的目标进程相关的标注 ("next:" 为前缀)：

	991963.885734 [0001]             :17008[17008]                                        awakened: sleep[16999]
	991963.885740 [0001]   s         :17008[17008]          25.613      0.000      0.057  next: sleep[16999]
	991963.886005 [0001]             sleep[16999]                                         awakened: perf[16984]
	991963.886009 [0001]   s         sleep[16999]         1000.104      0.006      0.269  next: cc1[17008]
	991963.886018 [0005]       s     cc1[17083]             19.998      0.000      9.948  next: perf[16984]

当 sleep 结束后，正在等待的 "cc1" 进程被执行。随后的上下文切换， perf 命令被执行，并且它是最后一个调度事件 (因为 perf 命令最后退出了)。笔者给社区提交了一个 patch，
通过 -n 命令选项，用以支持显示上下文切换的目标进程。

## 4. perf sched script ##

`perf sched script` 子命令用来显示所有原始调度事件 (raw event)，与 `perf script` 的作用类似：

	# perf sched script
	    perf 16984 [005] 991962.879960: sched:sched_stat_runtime: comm=perf pid=16984 runtime=3901506 [ns] vruntime=165...
	    perf 16984 [005] 991962.879966:       sched:sched_wakeup: comm=perf pid=16999 prio=120 target_cpu=005
	    perf 16984 [005] 991962.879971:       sched:sched_switch: prev_comm=perf prev_pid=16984 prev_prio=120 prev_stat...
	    perf 16999 [005] 991962.880058: sched:sched_stat_runtime: comm=perf pid=16999 runtime=98309 [ns] vruntime=16405...
	     cc1 16881 [000] 991962.880058: sched:sched_stat_runtime: comm=cc1 pid=16881 runtime=3999231 [ns] vruntime=7897...
	  :17024 17024 [004] 991962.880058: sched:sched_stat_runtime: comm=cc1 pid=17024 runtime=3866637 [ns] vruntime=7810...
	     cc1 16900 [001] 991962.880058: sched:sched_stat_runtime: comm=cc1 pid=16900 runtime=3006028 [ns] vruntime=7772...
	     cc1 16825 [006] 991962.880058: sched:sched_stat_runtime: comm=cc1 pid=16825 runtime=3999423 [ns] vruntime=7876...

上面输出对应的每一个事件 (如 sched:sched_stat_runtime)，都与内核调度器相关代码里的 tracepoint 相对应，这些 tracepoint 都可以使用 `perf record` 来直接激活并且记录其对应事件。
如前文所示，这些原始调度事件 (raw event) 可以用来帮助理解和解释其它 `perf sched` 子命令的相关输出。

就酱，玩得高兴！

## 5. References ##

* [perf sched for Linux CPU scheduler analysis](http://www.brendangregg.com/blog/2017-03-16/perf-sched.html)
* [perf exmaples](http://www.brendangregg.com/perf.html#SchedulerAnalysis)
* [eBPF/bcc](https://github.com/iovisor/bcc)
* [runqlat](http://www.brendangregg.com/blog/2016-10-08/linux-bcc-runqlat.html)
