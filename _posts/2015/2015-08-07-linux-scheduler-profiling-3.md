---
layout: post
title: Linux scheduler profiling - 3
description: Leverage schestats provided by Linux, any app latency could be devided by CPU time, runq wait time and sleep time.
categories: [English, Software]
tags:
- [scheduler, perf, kernel, linux]
---

>The content reuse need include the original link: <http://oliveryang.net>

* content
{:toc}

### 1. Challenges of OS latency analysis

For most of user application developers, to dig out the root cause of code latency is kind of challenge, because following issues need to be addressed,

* How to define the latency issue clearly

  People may not have common sense about bad latency value. Furthermore, different latency causes require to collect different debug information.
  It is not easy to define a perf latency problem by collecting all proper debug information one time.

* How to avoid trial-and-error overheads

  Latency root causes could be various, and repeat trial-and-error process is painful.

* How to debug latency issue at fine granularity

  Most of people are familiar with system level tools, which could not help on function level latency issue.

### 2. Latency breakdown

For any of Linux threads/processes, it should be always under one of 3 status below,

1. Running on CPU
2. Waiting on per-CPU run queue, ready for scheduling
3. Under sleep status, may be woken up later

Then the latency breakdown could be,

> Latency = CPU run time + Run queue wait time + Sleep time

When we do latency bug triage, if we can always get latency breakdown with this way, that would give people a clear problem definition and debug
direction.

#### 2.1 CPU run time

TBD

#### 2.2 Run queue wait time

TBD

#### 2.3 Sleep time

TBD

### 3. Implementation

TBD
