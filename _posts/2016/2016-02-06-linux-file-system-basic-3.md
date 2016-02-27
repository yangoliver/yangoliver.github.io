---
layout: post
title: Linux File System Basic - 3
description: Linux file system(文件系统)模块的实现和基本数据结构。关键字：文件系统，内核，samplefs，VFS，存储。
categories:
- [Chinese, Software]
tags:
- [file system, crash, kernel, linux, storage]
---

>本文首发于 <http://oliveryang.net>，转载时请包含原文或者作者网站链接。

## 文件系统 mount 和 Super Block

Samplefs Day2 的代码涉及到了文件系统 mount 和 Super Block (超级块)的实现。
本文将以 [Day2 的代码](https://github.com/yangoliver/lktm/tree/master/fs/samplefs/day2)
为例，讲解相关概念。

### 1. Samplefs Day2

#### 1.1 源代码

与 Day1 相比，Day2 的实现增加了下面几个函数，

- samplefs_fill_super: 初始化 VFS Super Block。

  该回调在文件系统被 mount 时被调用。

  mount 在VFS文件系统的调用路径以系统调用 `sys_mount` 为起点，路径如下(内核版本3.19)，

	  sys_mount->do_mount->do_new_mount->vfs_kern_mount->mount_fs

  在 VFS 层面，由于 samplefs 早已在模块加载时就向其注册了文件系统类型，
  因此 VFS 可以很方便查找到 samplefs 在 samplefs_fs_type 里注册的入口函数 samplefs_mount，
  而 samplefs_mount 使用了 mount_nodev 方法，并把 samplefs_fill_super 回调作为参数传递给 mount_nodev,

	  samplefs_mount->mount_nodev

  mount_nodev 分配了新的 VFS Supoer Block 然后调用 samplefs_fill_super 回调做了如下几件事情，

  1. 分配 root inode
  2. 分配了属于 samplefs 模块的内存 Super Block: samplefs_sb_info，并让它在 VFS 层的 Super Block 指向它。
  3. 根据 root inode，分配 root dentry，作为 mount_nodev，也是 samplefs_mount 的最终返回值。
  4. 使用 load_nls_default() 函数初始化 samplefs 模块的内存 Super Block。
     主要用于 mount 时对不同编码字符集的支持, Linux NLS Kconfig 里有对 Native language support 的说明。
  5. 调用 samplefs_parse_mount_options 来解析 mount 时的选项参数。

- samplefs_parse_mount_options: 解析 mount 文件系统时的选项参数。

  这个函数的实现比较简单，值得说明的有两点，

  1. mount 时的选项参数是在 sys_mount 系统调用时从用户空间拷贝到内核内存中，
     再由 VFS 的代码通过 samplefs 的 mount 入口函数传入进来的。

  2. 解析后的选项参数保存在了 samplefs 模块的 Super Block：samplefs_sb_info 里。
     Samplefs 的 VFS Super Block 结构指向这个结构。

- samplefs_put_super: 释放 samplefs 模块的内存 Super Block。

  smaplefs 在mount的时候一共创建两个内存 Super Block，

  1. 存在于 samplefs 模块这层的内存 Super Block: `struct samplefs_sb_info`

     这个超级块是由 samplefs_fill_super 在 mount 时分配的，因此也正是由 samplefs_put_super 这个函数在 umount 时释放的。

     必须注意的是，samplefs_put_super 是 VFS 定义的标准回调函数，在 `struct super_operations` 里定义的，
     是 VFS Super Block 的标准方法。

  2. 存在于 VFS 层的 Super Block: `struct super_block`

     这个超级块在 mount 文件系统时，由 samplefs_mount 调用 mount_nodev 时由 VFS 的代码分配。
     而释放则是在 umount 命令触发调用 sys_umount 系统调用来释放的。

     在2.6内核，sys_umount 直接在当前上下文一直调用到 deactivate_super 来释放掉 VFS Super Block。

     而在3.19内核，sys_umount 则在调用 mntput_no_expire 时引入了异步执行的逻辑，
     把释放 VFS Super Block的任务交给另外一个线程去做。但如果 MNT_INTERNAL 标志被置位，
     则意味着 umount 是从内核态发起的，对内核态发起的 umount 则仍旧使用当前上下文，
     即同步的方式去释放 VFS Super Block。下面的代码片段就来自 mntput_no_expire，

         if (likely(!(mnt->mnt.mnt_flags & MNT_INTERNAL))) { /* 不属于 MS_KERNMOUNT 的方式 */
             struct task_struct *task = current;
             if (likely(!(task->flags & PF_KTHREAD))) { /* 不是内核线程，要返回用户态 */
                init_task_work(&mnt->mnt_rcu, __cleanup_mnt);
                if (!task_work_add(task, &mnt->mnt_rcu, true)) /* 返回用户态必须用这个函数才保证正确 */
                    return;
             }
             if (llist_add(&mnt->mnt_llist, &delayed_mntput_list)) /* 内核线程，又不属于 MS_KERNMOUNT，为何不用同步方式? */
                 schedule_delayed_work(&delayed_mntput_work, 1);   /* 用 workqueue 异步执行是因为可能中断上下文？*/
             return;
         }
         cleanup_mnt(mnt); /* 因为设置 MS_KERNMOUNT，不返回用户态，可以使用同步方式 */

     这个被称作 [delayed mntput 的patch](https://github.com/torvalds/linux/commit/9ea459e110df32e60a762f311f7939eaa879601d)
     在3.18-rc1被引入。关于为何要引入 delayed mntput 和 task_work_add API 有何特殊的意义，
     [LWN 讲述 delay fput 的文章](https://lwn.net/Articles/494158/)对理解这些问题很有帮助。

#### 1.2 编译和加载

编译 Day2 模块需要先编译 Linux 内核源代码。请参考
[Linux File System Basic - 2](http://oliveryang.net/2016/01/linux-file-system-basic-2/)。

Samplefs 的编译可以在 Linux 内核编译成功后，运行下面的命令单独编译，

	make M=/ws/lktm/fs/samplefs/day2

原版的 Day2 的代码是为 Linux 2.6 写的，在新内核 Linux 3.19 上会因为内核接口的变化引起编译错误。
如果使用本文提供的 Day2 的源码，则可以正确编译，这是因为本文所用代码对新内核做了相应的修改。
请参考[针对新内核接口的 Patch](https://github.com/yangoliver/lktm/commit/dd2b5a7332ff61ee8a4ded3281616b0f77d6eddf#diff-2e79772ae929f397a8bb5817fc4e6c4f)
来查看本文中的 Day2 代码针对原有代码做了哪些修改。

### 2. 相关概念和接口

TBD

#### 2.1 Super Block

#### 2.2 mount 实例

### 3. 实验和调试

TBD

#### 3.1 文件系统 mount

#### 3.2 遍历 mount 实例

#### 3.3 查看 Super Block

### 4. 小结
