---
layout: post
title: Linux Crash Utility - page cache debug
categories:
- English
tags:
- [crash, kernel, linux]
---

Recently, my [file page cache dump patch](https://github.com/crash-utility/crash/commit/3106fee2bebfdb0f1c850911f452824237598d92)
got merged to crash upstream.
This patch supports dumping file page cache by extending two new options for files command: -c and -p.

Below are the examples copied from "help files" output,

    For each open file, display the number of pages that are in the page cache:
  
      crash> files -c 1954
      PID: 1954   TASK: f7a28000  CPU: 1   COMMAND: "syslogd"
      ROOT: /    CWD: /
       FD   INODE    I_MAPPING  NRPAGES  TYPE  PATH
        0  cb3ae868   cb3ae910        0  SOCK  socket:/[4690]
        2  f2721c5c   f2721d04      461  REG   /var/log/messages
        3  cbda4884   cbda492c       47  REG   /var/log/secure
        4  e48092c0   e4809368       58  REG   /var/log/maillog
        5  f65192c0   f6519368       48  REG   /var/log/cron
        6  e4809e48   e4809ef0        0  REG   /var/log/spooler
        7  d9c43884   d9c4392c        0  REG   /var/log/boot.log
  
    For the inode at address f59b90fc, display all of its pages that are in
    the page cache:
  
      crash> files -p f59b90fc
       INODE    NRPAGES
      f59b90fc        6
  
        PAGE    PHYSICAL   MAPPING   INDEX CNT FLAGS
      ca3353e0  39a9f000  f59b91ac        0  2 82c referenced,uptodate,lru,private
      ca22cb20  31659000  f59b91ac        1  2 82c referenced,uptodate,lru,private
      ca220160  3100b000  f59b91ac        2  2 82c referenced,uptodate,lru,private
      ca1ddde0  2eeef000  f59b91ac        3  2 82c referenced,uptodate,lru,private
      ca36b300  3b598000  f59b91ac        4  2 82c referenced,uptodate,lru,private
      ca202680  30134000  f59b91ac        5  2 82c referenced,uptodate,lru,private

Here is a useful two steps debug scenario,

- Step 1: Find out which files have big page caches by a system wide search.

For example, below command can show you top 10 page cache consumers,

    crash> foreach files -c -R REG | sort -k4 -nr | head -n10
      5 ffff88000ca8a000 ffff88000ca8a158   43525 REG  /usr/lib/debug/lib/modules/4.0.4-301.fc22.x86_64/vmlinux
      7 ffff88003bc76650 ffff88003bc767a8    1460 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/system.journal
     22 ffff88003bc76650 ffff88003bc767a8    1460 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/system.journal
      9 ffff88003bc7ea38 ffff88003bc7eb90    1305 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/user-1000.journal
     33 ffff88003bc7ea38 ffff88003bc7eb90    1305 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/user-1000.journal
     10 ffff88003bca4328 ffff88003bca4480     819 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/system@000519dba3929edf-3c21d3156cdac9e1.journal~
      6 ffff88003c6ade80 ffff88003c6adfd8     500 REG  /etc/udev/hwdb.bin
      8 ffff88003bc7e650 ffff88003bc7e7a8     495 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/system@000519ef739145cf-66834870ad2eb7de.journal~
     11 ffff88003c6ac710 ffff88003c6ac868     492 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/system@000519f9a34ea968-08789e6264d9853f.journal~
      6 ffff88003bc7e268 ffff88003bc7e3c0     213 REG  /var/log/journal/1c702f9650c743ba9d4508756fc7c861/system@000519c451c742e0-0961fb61e12ba82d.journal~

- Step 2: Check how many dirty pages for one specific file by below command,


    crash> files -p <inode_addr\> | grep -i dirty | wc -l


Please note that on a live kernel, you may not be able to dump pages in page cache, because the memory content could be
changed by kernel at same time, due to file IO operations.

Another interesting example is using files command to dump file content in memory.

- Under Linux bash, I can show you first 12 lines in this blog file. 
  
It is a plain text file written by Markdown language.

    $ head -n12 2015-07-03-linux-crash-file-page-cache.md
    ---
    layout: post
    title: Linux Crash Utility - file page cache
    categories:
    - English
    tags:
    - [crash, kernel, linux]
    ---
    Recently, my [file page cache dump patch](https://github.com/crash-utility/crash/commit/3106fee2bebfdb0f1c850911f452824237598d92)
    got merged to crash upstream.

- Now, under crash prompt, we can search which process opened my blog file. 

You can see, process "vim", pid 2285 is opening the blog file.

    crash> foreach files -c -R 2015-07-03
    PID: 2285   TASK: ffff88003c216d50  CPU: 0   COMMAND: "vim"
    ROOT: /    CWD: /home/oliver/ws/yangoliver.github.io/_posts/2015
     FD      INODE          I_MAPPING     NRPAGES TYPE PATH
      4 ffff88000ca64ee0 ffff88000ca65038       3 REG  /home/oliver/ws/yangoliver.github.io/_posts/2015/.2015-07-03-linux-crash-file-page-cache.md.swp

- Next step is to dump all pages belong to this blog file.

There are 3 pages in the page cache.
    
    crash> files -p ffff88000ca64ee0
         INODE        NRPAGES
    ffff88000ca64ee0        3
    
          PAGE       PHYSICAL      MAPPING       INDEX CNT FLAGS
    ffffea00004f5c80 13d72000 ffff88000ca65038        0  2 3ffff80000086c referenced,uptodate,lru,active,private
    ffffea00004ff9c0 13fe7000 ffff88000ca65038        1  2 3ffff80000086c referenced,uptodate,lru,active,private
    ffffea00003421c0  d087000 ffff88000ca65038        2  2 3ffff80000086c referenced,uptodate,lru,active,private

- Finally, the blog content could be found in third page.

You can see the content is exactly same with the output under bash, but we read them from raw memory page!

    crash> rd -p -a d087000 4096 | tail -12
             d087ee8:  got merged to crash upstream.
             d087f06:  Recently, my [file page cache dump patch](https://github.com
             d087f42:  /crash-utility/crash/commit/3106fee2bebfdb0f1c850911f4528242
             d087f7e:  37598d92)
             d087f89:  ---
             d087f8d:  - [crash, kernel, linux]
             d087fa6:  tags:
             d087fac:  - English
             d087fb6:  categories:
             d087fc2:  title: Linux Crash Utility - file page cache
             d087fef:  layout: post
             d087ffc:  ---


Overall, the new files command option is quite powerful, and it could work smoothly with existing files command options.
When you ran into any page cache bugs, the new options may give you powerful aids.

It is time to enjoy hacking Linux kernel by the new version (7.1.2) [Linux crash tool](https://github.com/crash-utility/).
Good luck!
