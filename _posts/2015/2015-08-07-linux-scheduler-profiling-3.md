---
layout: post
title: Linux scheduler profiling - 3
categories:
- [English, OS]
tags:
- [scheduler, perf, kernel, linux]
---

##Fine granularity latency analysis

###Background

1. Challenges of OS latency analysis

	For most of user application developers, to dig out the root cause of code latency is kind of challenge in real world because,

	* How to avoid trial-and-error overheads

	  Latency root causes could be various, and not easy to guess.

	* When latency issues are related to system call latency.

	  Especially the system call latency is worked as async mode, more than one process context got involved.
	  Or the sync mode system call just has very complicate code path, difficult to understand by non-expert.

	* When latency issues could be only debugged at fine granularity.

	  This might be very common, the issues just happen in a small piece of function, but it is difficult to do the perf profiling
	  at function level. For example, the function is scheduled with user space threads pool, but your Linux version does not support
	  the feature like ```uprobe```, which allows trace user space function dynamically. Or, the OS is very old, cannot support dynamic
	  tracing functionalities.

	* Perf bug reproduce cost is high

	  When a perf bug could not be reproduced by a micro-benchmark, which means bug reproduce and debug cost are quite high.

2. TBD.
