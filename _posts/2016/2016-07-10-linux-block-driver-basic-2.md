---
layout: post
title: Linux Block Driver - 2
description: Linux 块设备驱动系列文章。通过开发简单的块设备驱动，掌握 Linux 块设备层的基本概念。
categories: [Chinese, Software, Hardware]
tags: [driver, crash, kernel, linux, storage]
---

> 文本处于写作状态，内容随时可能有更改。

> 本文首发于<http://oliveryang.net>，转载时请包含原文或者作者网站链接。

* content
{:toc}

## 1. 背景

在 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1) 中，我们实现了一个最简块设备驱动 Sampleblk。
这个只有 200 多行源码的块设备驱动利用内存创建了标准的 Linux 磁盘。我们在基于 Linux 4.6.0 内核的环境下，加载该驱动，并在其上创建了 Ext4 文件系统。

本文将继续之前的实验，围绕 Sampleblk 探究 Linux 块设备驱动的运作机制。

## 2. 准备


首先，在阅读本文前，请按照 [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
中的步骤准备好实验环境。确保可以做到如下步骤，

- 编译和加载 Sampleblk Day1 驱动
- 用 Ext4 格式化 /dev/sampleblk1
- mount 文件系统到 /mnt

其次，为了继续后续实验，还需做如下准备工作。

- 安装 fio 测试软件。

  [fio](https://github.com/axboe/fio) 是目前非常流行的 IO 子系统测试工具。作者 Jens Axboe 是 Linux IO 子系统的 maintainer，目前就职于 Facebook。
  互联网上 FIO 安装和使用的文章很多，这里就不在赘述。不过最值得细读的还是 [fio HOWTO](https://github.com/axboe/fio/blob/master/HOWTO)。

- 安装 blktrace 工具。

  也是 Jens Axboe 开发的 IO 子系统追踪和性能调优工具。发行版有安装包。关于该工具的使用可以参考 [blktrace man page](http://linux.die.net/man/8/blktrace)。

- 安装 Linux Perf 工具。

  Perf 是 Linux 源码树自带工具，运行时动态追踪，性能分析的利器。也可以从发行版找到安装包。
  网上的 Perf 使用介绍很多。[Perf Wiki](https://perf.wiki.kernel.org/index.php/Main_Page) 非常值得一看。

- 下载 perf-tools 脚本。

  [perf-tools 脚本](https://github.com/brendangregg/perf-tools) 是 Brendan Gregg 写的基于 ftrace 和 perf 的工具脚本。全部由 bash 和 awk 写成，无需安装，非常简单易用。
  [Ftrace: The hidden light switch](http://lwn.net/Articles/608497) 这篇文章是 Brendan Gregg 给 LWN 的投稿，推荐阅读。 

## 3. 实验与分析

### 3.1 文件顺序写测试

如一般 Linux 测试工具支持命令行参数外，fio 也支持 job file 的方式定义测试参数。
本次实验中使用的 [fs_seq_write_sync_001](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/fs_seq_write_sync_001) job file 内容如下，

	; -- start job file --
	[global]            ; global shared parameters
	filename=/mnt/test  ; location of file in file system
	rw=write            ; sequential write only, no read
	ioengine=sync       ; synchronized, write(2) system call
	bs=,4k              ; fio iounit size, write=4k, read and trim are default(4k)
	iodepth=1           ; how many in-flight io unit
	size=2M             ; total size of file io in one job
	loops=1000000       ; number of iterations of one job

	[job1]              ; job1 specific parameters

	[job2]              ; job2 specific parameters
	; -- end job file --

本次实验将在 /dev/sampleblk1 上 mount 的 Ext4 文件系统上进行顺序 IO 写测试。其中 fio 将启动两个测试进程，同时对 /mnt/test 文件进行写操作。

	$ sudo fio ./fs_seq_write_sync_001
	job1: (g=0): rw=write, bs=4K-4K/4K-4K/4K-4K, ioengine=sync, iodepth=1
	job2: (g=0): rw=write, bs=4K-4K/4K-4K/4K-4K, ioengine=sync, iodepth=1
	fio-2.1.10
	Starting 2 processes
	Jobs: 2 (f=2): [WW] [0.4% done] [0KB/1376MB/0KB /s] [0/352K/0 iops] [eta 51m:05s]
	...[snipped]...

从 fio 的输出中可以看到 fio 启动了两个 job，并且按照 job file 规定的设置开始做文件系统写测试。

### 3.2 文件 IO Pattern 分析

#### 3.2.1 使用 strace

首先，我们可以先了解一下 fio 测试在系统调用层面看的 IO pattern 是如何的。Linux 的 `strace` 工具是跟踪应用使用系统调用的常用工具。

在 fio 运行过程中，我们获得 fio 其中一个 job 的 pid 之后，运行了如下的 `strace` 命令，

	$ sudo strace -ttt -T -e trace=desc -C -o ~/strace_fio_fs_seq_write_sync_001.log -p 94302

[`strace` man page](http://linux.die.net/man/1/strace) 给出了命令的详细用法，这里只对本小节里用到的各个选项做简单的说明，

- `-ttt` 打印出每个系统调用发生的起始时间戳。
- `-T` 则给出了每个系统调用的开销。
- `-e trace=desc` 只记录文件描述符相关系统调用。这样可过滤掉无关信息，因为本实验是文件顺序写测试。
- `-C` 则在 `strace` 退出前可以给出被跟踪进程的系统调用在 `strace` 运行期间使用比例和次数的总结。
- `-o` 则指定把 `strace` 的跟踪结果输出到文件中去。

#### 3.2.2 分析 strace 日志

根据 strace 的跟踪日志，我们可对本次 fio 测试的 IO pattern 做一个简单的分析。
详细日志信息请访问[这里](https://github.com/yangoliver/lktm/blob/master/drivers/block/sampleblk/labs/lab1/strace_fio_fs_seq_write_sync_001.log)，下面只给出其中的关键部分，

	1466326568.892873 open("/mnt/test", O_RDWR|O_CREAT, 0600) = 3 <0.000013>
	1466326568.892904 fadvise64(3, 0, 2097152, POSIX_FADV_DONTNEED) = 0 <0.000813>
	1466326568.893731 fadvise64(3, 0, 2097152, POSIX_FADV_SEQUENTIAL) = 0 <0.000004>
	1466326568.893744 write(3, "\0\260\35\0\0\0\0\0\0\320\37\0\0\0\0\0\0\300\35\0\0\0\0\0\0\340\37\0\0\0\0\0"..., 4096) = 4096 <0.000020>

	[...snipped (512 write system calls)...]

	1466326568.901551 write(3, "\0p\27\0\0\0\0\0\0\320\37\0\0\0\0\0\0\300\33\0\0\0\0\0\0\340\37\0\0\0\0\0"..., 4096) = 4096 <0.000006>
	1466326568.901566 close(3)              = 0 <0.000008>

	[...snipped (many iterations of open, fadvise64, write, close)...]

	% time     seconds  usecs/call     calls    errors syscall
	------ ----------- ----------- --------- --------- ----------------
	 72.55    0.192610           2     84992           write
	 27.04    0.071788         216       332           fadvise64
	  0.28    0.000732           4       166           open
	  0.13    0.000355           2       166           close
	------ ----------- ----------- --------- --------- ----------------
	100.00    0.265485                 85656           total

根据 `strace` 日志，我们可以对 fio 顺序文件写测试的详细步骤做出如下分析，

1. 调用 `open` 在 Ext4 上以读写方式打开 /mnt/test 文件，若不存在则创建一个。

   因为 fio job file 指定了文件名，filename=/mnt/test
2. 调用 `fadvise64`，使用 POSIX_FADV_DONTNEED 丢弃 /mnt/test 在 page cache 里的数据。

   fio 做文件 IO 前，清除 /mnt/test 文件的 page cache，可以让测试避免受到 page cache 影响。

3. 调用 `fadvise64`，使用 POSIX_FADV_SEQUENTIAL 提示内核应用要对 /mnt/test 做顺序 IO 操作。

   这是因为 fio job file 定义了 rw=write，因此这是顺序写测试。
4. 调用 `write` 对 /mnt/test 写入 4K 大小的数据。一共 write 512 次，共 2M 数据。

   这是因为 fio job file 定义了 ioengine=sync，bs=,4k，size=2M。

5. 调用 `close` 完成一次 /mnt/test 顺序写测试。重复上述过程，反复迭代。

   fio job file 定义了 loops=1000000

### 3.3 深入理解文件 IO

TBD

#### 3.3.1 使用 ftrace

#### 3.3.2 open

#### 3.3.3 fadvise64

#### 3.3.4 write

#### 3.3.5 close

## 4. 小结

## 5. 延伸阅读

* [Linux Block Driver - 1](http://oliveryang.net/2016/04/linux-block-driver-basic-1)
* [Linux Crash - background](http://oliveryang.net/2015/06/linux-crash-background/)
* [Linux Crash - page cache debug](http://oliveryang.net/2015/07/linux-crash-page-cache-debug/)
* [Ftrace: The hidden light switch](http://lwn.net/Articles/608497)
* [Device Drivers, Third Edition](http://lwn.net/Kernel/LDD3)
