---
layout: post
title: Linux Crash - background
description: Linux kernel debug tool - crash introduction. 用crash来调试Linux内核错误是内核程序员的基本技能。
categories: [English, Software]
tags: [crash, kernel, linux, solaris]
---

>The content reuse need include the original link: <http://oliveryang.net>

* content
{:toc}

### 1. What is the crash tool?

The quotes from crash [README](https://github.com/crash-utility/crash/blob/master/README),

>The core analysis suite is a self-contained tool that can be used to investigate
>either live systems, kernel core dumps created from dump creation facilities such
>as kdump, kvmdump, xendump, the netdump and diskdump.

The similar debug tool on Solaris is [mdb](https://en.wikipedia.org/wiki/Modular_Debugger). Many years ago, when I was a
Solaris developer, hacking kernel by mdb was an exciting experiment in my work. I used to write
[a blog series](http://blog.csdn.net/yayong/article/details/1520604) to show how to debug Solaris kernel by mdb.

Today, I extended my kernel hacking experiences to Linux. Crash has replaced mdb in my kernel hacking life now.

### 2. What is the major use case? How about other debug tools?

The major use case is kernel **post-mortem debugging**, as known as, **core dump analysis**.

For kernel core file analysis, gdb does not have enough knowledge about kernel. For example, gdb may not print the kernel
thread back trace correctly because of lack of knowledge about various kernel stacks for NMI, exceptions, and regular tasks.

In Linux world, gdb can be used as front-end for kernel debugger [kgdb](https://en.wikipedia.org/wiki/KGDB). As far as I know,
kgdb is not designed for post-mortem debugging. For kernel debugger like kgdb/kdb, I call it **in situ kernel debugger**, or
online debugger.

In Solaris word, the similar tool is [kmdb](http://docs.oracle.com/cd/E19253-01/816-5165/6mbb0m9is/index.html), which is
more powerful than Linux [kdb](https://kgdb.wiki.kernel.org/index.php/KDB_FAQ). Solaris kmdb have the knowledge of kernel data
structures, whereas the Linux kdb does not have. But Linux kgdb can debug kernel at c code level, Solaris kmdb can not.
However, debugging at assembly language level is still a **must to have** knowledge for a kernel developer.

Anyway, on Linux crash is the only tool for kernel post-mortem debugging. For in situ kernel debugger, you could use
triditional tools like kdb/kgdb, or new kernel trace tools like perf, systemtap, ftrace, dtrace, and so on.

### 3. Where can I found the documents?

Please refer to [README](https://github.com/crash-utility/crash/blob/master/README). A whitepaper with complete documentation
concerning the use of this utility can be found in this README as well.

In practice, you can get all command usages by help under **crash>** prompt.

### 4. Where can I found the source code? How can I contribute the code?

It is hosted from [Github](https://github.com/crash-utility). The project does not accept the regular Github pull
requests for code contribution. People have to mail patches to the crash utility mailing list:

>crash-utility@redhat.com

Crash is licensed at **GPLv3**. If you are working for commercial purpose, please follow the legal process in your organization
for open source code contribution or tools integration in your commercial software.

It is not possible to cover everything here. For further information, please refer to README or raise your questions to mail list.
Have fun!
