---
layout: post
title: Linux scheduler profiling - 2
categories:
- [English, OS]
tags:
- [scheduler, perf, kernel, linux]
---

##SCHEDSTATS profiling - part 1

1. What is the SCHEDSTATS?

    SCHEDSTATS is a kernel debug feature which allows scheduler exports its pre-defined performance counters to user space.
    We can do following things by collecting and analyzing these perf counters, 
    
      * Debug or tune scheduler
      * Debug or tune specific application or benchmark from scheduling perspective

2. How could we access SCHEDSTATS counters?
    
    When SCHEDSTATS is enabled, scheduler statistics could be accessed by following ways,

	  * Three proc files exported by SCHEDSTATS code

	    /proc/schedstat, /proc/<pid\>/schedstat, /proc/<pid\>/sched
	   
	    [Documentation/scheduler/sched-stats.txt](https://github.com/torvalds/linux/blob/master/Documentation/scheduler/sched-stats.txt)
		file has the full description for file format.
		We can write user space tools to read and process the proc files.

	  * pre-defined kernel trace points

	    Kernel trace points could be used by dynamic tracing tools, such as systemtap, perf.
	    So far, in Linux 4.1, there are 4 sched_stat_* trace points defined by SCHEDSTATS code, there are 4 sched_stat_*
	    trace points defined by SCHEDSTATS code.

		<pre> # perf list | grep sched_stat_
		  sched:sched_stat_wait              [Tracepoint event]
		  sched:sched_stat_sleep             [Tracepoint event]
		  sched:sched_stat_iowait            [Tracepoint event]
		  sched:sched_stat_blocked           [Tracepoint event]
		  sched:sched_stat_runtime           [Tracepoint event] >>>> Not a SCHEDSTAT trace point</pre>

	    Linux perf tool, record, report, script sub-commands could be used for getting system wide or per-task statistics.

	  * sleep profiler when SCHEDSTATS is enabled

	    This needs readprofile command installed in user space.
		The usage of readprofile could be found from [Documentation/basic_profiling.txt](https://github.com/torvalds/linux/blob/master/Documentation/basic_profiling.txt).
		To enable kernel profiler, please refer to [Documentation/kernel-parameters.txt](https://github.com/torvalds/linux/blob/master/Documentation/kernel-parameters.txt).
		This way is a **legacy** way and could be replaced by following trace point in latest kernel,
		
		<pre> # perf list | grep sched_stat_blocked
		  sched:sched_stat_blocked                           [Tracepoint event]
		# perf record -e sched:sched_stat_blocked -a -g sleep 5
        # perf script</pre>

3. SCHEDSTATS proc files use cases

	* System wide statistic

	  This includes per-cpu(run queue) or per-sched-domain statistics.
    
        **/proc/schedstat**

	    Implements in scheduler core, which is the common layer for all scheduling classes.

		The	CPU statistics in /proc/schedstat file is defined as members of ```struct rq``` in kernel/sched.c,
			
			struct rq {
				[...snipped...]
	
			#ifdef CONFIG_SCHEDSTATS
				/* latency stats */
				struct sched_info rq_sched_info;
				unsigned long long rq_cpu_time;
				/* could above be rq->cfs_rq.exec_clock + rq->rt_rq.rt_runtime ? */
			
				/* sys_sched_yield() stats */
				unsigned int yld_count;
			
				/* schedule() stats */
				unsigned int sched_switch;
				unsigned int sched_count;
				unsigned int sched_goidle;
			
				/* try_to_wake_up() stats */
				unsigned int ttwu_count;
				unsigned int ttwu_local;
			#endif
	
				[...snipped...]
			};
	
		The Domain statistics in /proc/schedstat file is defined as members of ```struct sched_domain```
		in include/linux/sched.h,
		
			struct sched_domain {
				[...snipped...]
			
			#ifdef CONFIG_SCHEDSTATS
				/* load_balance() stats */
				unsigned int lb_count[CPU_MAX_IDLE_TYPES];
				unsigned int lb_failed[CPU_MAX_IDLE_TYPES];
				unsigned int lb_balanced[CPU_MAX_IDLE_TYPES];
				unsigned int lb_imbalance[CPU_MAX_IDLE_TYPES];
				unsigned int lb_gained[CPU_MAX_IDLE_TYPES];
				unsigned int lb_hot_gained[CPU_MAX_IDLE_TYPES];
				unsigned int lb_nobusyg[CPU_MAX_IDLE_TYPES];
				unsigned int lb_nobusyq[CPU_MAX_IDLE_TYPES];
			
				/* Active load balancing */
				unsigned int alb_count;
				unsigned int alb_failed;
				unsigned int alb_pushed;
			
				/* SD_BALANCE_EXEC stats */
				unsigned int sbe_count;
				unsigned int sbe_balanced;
				unsigned int sbe_pushed;
			
				/* SD_BALANCE_FORK stats */
				unsigned int sbf_count;
				unsigned int sbf_balanced;
				unsigned int sbf_pushed;
			
				/* try_to_wake_up() stats */
				unsigned int ttwu_wake_remote;
				unsigned int ttwu_move_affine;
				unsigned int ttwu_move_balance;
			#endif
		
				[...snipped...]
			};

	* Per task statistic

      **/proc/<pid\>/schedstat**

	    Common for all scheduling classes.

		The statistics for /proc/<pid\>/schedstat is defined as member of ```struct task_struct``` in include/linux/sched.h,
	
			#if defined(CONFIG_SCHEDSTATS) || defined(CONFIG_TASK_DELAY_ACCT)
			struct sched_info {
				/* cumulative counters */
				unsigned long pcount;	      /* # of times run on this cpu */
				unsigned long long run_delay; /* time spent waiting on a runqueue */
			
				/* timestamps */
				unsigned long long last_arrival,/* when we last ran on a cpu */
						   last_queued;	/* when we were last queued to run */
			};
		  	#endif /* defined(CONFIG_SCHEDSTATS) || defined(CONFIG_TASK_DELAY_ACCT) */
	
	
			struct task_struct {
				[...snipped...]
			
			#if defined(CONFIG_SCHEDSTATS) || defined(CONFIG_TASK_DELAY_ACCT)
				struct sched_info sched_info;
			#endif
			
				[...snipped...]
			};

	  **/proc/<pid\>/sched**

	    Only available for CFS tasks. Need enable SCHED_DEBUG as well.

		The se statistics for /proc/<pid\>/sched is defined as member of ```struct task_struct``` in include/linux/sched.h,
	
		
			#ifdef CONFIG_SCHEDSTATS
			struct sched_statistics {
				u64			wait_start;
				u64			wait_max;
				u64			wait_count;
				u64			wait_sum;
				u64			iowait_count;
				u64			iowait_sum;
			
				u64			sleep_start;
				u64			sleep_max;
				s64			sum_sleep_runtime;
			
				u64			block_start;
				u64			block_max;
				u64			exec_max;
				u64			slice_max;
			
				u64			nr_migrations_cold;
				u64			nr_failed_migrations_affine;
				u64			nr_failed_migrations_running;
				u64			nr_failed_migrations_hot;
				u64			nr_forced_migrations;
			
				u64			nr_wakeups;
				u64			nr_wakeups_sync;
				u64			nr_wakeups_migrate;
				u64			nr_wakeups_local;
				u64			nr_wakeups_remote;
				u64			nr_wakeups_affine;
				u64			nr_wakeups_affine_attempts;
				u64			nr_wakeups_passive;
				u64			nr_wakeups_idle;
			};
			#endif
	
	
			struct sched_entity {
				[...snipped...]
	
			#ifdef CONFIG_SCHEDSTATS
				struct sched_statistics statistics;
			#endif
	
				[...snipped...]
			};
	
	
			struct task_struct {
				[...snipped...]
	
				struct sched_entity se;
	
				[...snipped...]
			};


4. SCHEDSTATS source files

	To use SCHEDSTATS, need to enable kernel config ```SCHEDSTATS```. All related code is protected by CONFIG_SCHEDSTATS.

	As far as we know, Linux kernel scheduler defined two layers,

	- The upper layer is scheduler core which is common layer for all scheduling class.

      In Linux 3.2.x, The SCHEDSTATS source files in scheduler common layer are,

	  **include/linux/sched.h**
	  
	  Per-sched-domain and per-task perf counters definitions.

	  **kernel/sched_stats.h**
	  
	  /proc/schestat proc file implementation

	  **fs/proc/base.c**

	  /proc/<pid\>/schedstat proc file implementation

	  **kernel/sched.c**

	  Per-runqueue perf counters definitions.

	  Per-runqueue, per-sched-domain, per-task perf counters implementation, for example, ttwu_stat

	  **kernel/profile.c**
	  
	  The legacy code, profiling code for /proc/profile support, readprofile(1) could read it.

	  **kernel/sched_debug.c**
	  
	  SCHEDSTATS in /proc/sched_debug and /proc/<pid\>/sched proc files implementation.
	  Need enable SCHED_DEBUG at same time.

	- The underlying layer is per scheduling class source code.

	  In Linux 3.2.x, only the CFS scheduling class code has the SCHEDSTATS implementation.

	  **kernel/sched_fair.c**
	  
	  SCHEDSTATS in /proc/<pid\>/sched. Need enable SCHED_DEBUG at same time.

	  /proc/schedstat counters for load balance.

	  Kernel Trace points for wait, sleep, iowait, blocked(not in 3.2.x) events. See section 3 in this blog.
