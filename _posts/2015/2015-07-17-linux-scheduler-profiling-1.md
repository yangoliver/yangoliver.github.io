---
layout: post
title: Linux scheduler profiling - 1
description: Linux kernel scheduling perf profiling goals. The major symptoms of scheduling perf issues.
categories: [English, Software]
tags:
- [scheduler, perf, kernel, linux]
---

>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

* content
{:toc}

### 1. Scheduling perf profiling goals

For an OS scheduler implementation, there are 3 key features,

* Time Sharing

	Let multiple tasks share the CPU time fairly and efficiently.

* Preemption

	Important or latency sensitive tasks could be scheduled as quick as possible.

* Load balance

	Allow multiple tasks to share multiple CPU resources in system wide fairly and efficiently.

If system ran into any CPU scheduling perf problems, we would see one of above features might get broken.
Our scheduling perf profiling goal is to understand how scheduler behaves from these 3 perspectives, under a certain
workload or benchmark.

### 2. The major symptoms of scheduling perf issues

The symptoms of scheduling perf issues could be also classified by above 3 perspectives,

* High or Low CPU utilization

* Big task scheduling latency

* Imbalance CPU utilization or scheduling latency

Please note that above symptoms might not always be caused by a kernel scheduler bug.
For this reason, the **most important thing** is, we must define the performance problem with a clear baseline.
With a clear baseline, we could have better efficiency to rule out different possibilities which have the similar symptoms.

### 3. The scheduling perf issues triage process

Different issues from hardware, kernel, or application level could cause the similar symptoms.

For example, I used to handle the CPU high utilization bug caused by wrong MTRR(Memory Type Range Register) setting.
In another case, the scheduling domain workload imbalance was caused by a buggy ACPI SART table. In my examples, these
issues might be easily identified by CPI(cycle per instruction) number reported by Linux perf or NUMAtop tools. However,
if the problems comes from kernel or application, it can be very difficult to get the root cause, when we do not have the
enough knowledge for that specific components.

As we always reported perf scheduling issues from specific type of workload or benchmark testing. The most efficient order
to triage scheduling performance bug is from top to bottom.

<pre>application -> kernel -> hypervisor -> hardware</pre>

One issues move from one layer to next layer, we must have technical justifications with following information,

* The clear problem definitions with clear performance baseline
* Why we think the problem is not in this layer
* The performance tracing data or logs that support your analysis
