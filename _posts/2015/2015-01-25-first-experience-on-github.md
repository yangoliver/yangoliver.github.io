---
layout: post
title: First experiences on Github
description: My first experience for github projects, which include irqbalance and perf-tools projects.
categories:
- [English, Software]
tags:
- [irqbalance, perf]
---

Finally I got my first development experiences on Github.

Before that, my development experience on Github was started from [my own tools](https://github.com/yangoliver/mytools/commits?author=yangoliver) in last year. I wrote some scripts to analysis Linux interrupt data from /proc/interrupt files.  But that is not a real Github open source project experiences.

This month, I submitted [my first pull request](https://github.com/Irqbalance/irqbalance/pull/14) to irqbalance project. People may already know, irqbalance project is an open source project for distribute irq work load among a multiple cores system. Most of Linux distributions, RHEL, Fedora, Centos, SUSE Linux are using it.

I ran into a performance issue caused by irqbalance PCI classification bug. Then I submitted this patch via Github.As I keep working on irqbalance issues recently, I think I will have more pull requests to irqbalance. 

[This link](https://github.com/Irqbalance/irqbalance/commits?author=yangoliver) could get all of my commits for irqbalance project.I hope it can grow more and more in follow months.

Although my fist pull request was from irqbalance, [my real first merge](https://github.com/brendangregg/perf-tools/pull/17) happen from perf-tools. The project owner [Brendan Gregg](http://www.brendangregg.com) is really a nice person. In [my another fsyncsnoop pull request](https://github.com/brendangregg/perf-tools/pull/18), he gave me very detailed review comments, and we had a great discussion there. Till now, it is still a pending request, but I did have better understanding for ftrace perf data analysis. Another important experience was, I wrote my first python script in fsyncsnoop. 

With these experiences, I have to say, Github is a really amazing place to all programmers. 

I feel like that I will be fully involved in Github activities (writing, coding) in my life.
