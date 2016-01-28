---
layout: post
title: Python and irqstat
description: Using irqstat to debug irqbalance problem。THis irqstat tool is numa aware debug tool。
categories:
- [English, Software]
tags:
- [irqbalance, perf, python]
---

While I was debugging irqbalance issue on a 4 socket Nodes machine, I realized that it is difficult to understand the perf data gathered by mpstat and /proc/interrupts. On this machine, there are 60 logical CPUs, it is very difficult to understand the output without tools helps. That is why I wrote some [interrupt tools](https://github.com/yangoliver/mytools/tree/master/interrupt) to help analysis on these outputs.

After I know [irqstat](https://github.com/lanceshelton/irqstat), I was really excited, and I thought this is the tool what I need for live monitor and analysis irq workload issues. I decided to integrate this tool into our product. However, irqstat does not provide the license information, which is quite important to us, as our legal team need that information for legal review process. Therefore, I learnt how to file a [bug/RFE](https://github.com/lanceshelton/irqstat/issues/1) via Github.

Several weeks later, I found another problem of irqstat. It could not be run at background mode due to its terminal control code. Also the its Python stdout is a kind of buffered IO, which will cause output could not be flushed immediately via the shell pipe. Thus, I worked out some patches to fix the problems. [This link](https://github.com/lanceshelton/irqstat/commits?author=yangoliver) could get all my patches to irqstat.

Irqstat is a small tool written by Python, but Python is not my programming language. Now it provided me a good opportunity to learn a new language. Python will be on my script language learning list, as I plan to do more performance related work in next year. With this efficient language, I think I will create more useful tools in my daily work.

Here is the output of irqstat on my 60 CPUs box. You can see that all interrupts are calculated as NUMA nodes, which is pretty cool:

    # irqstat
    interactive commands -- t: view totals, 0-9: view node, any other key: quit
     
    IRQs / 5 second(s)
    IRQ#     TOTAL     NODE0      NODE1      NODE2      NODE3  NAME
     136 337950405 337950405          0          0          0  PCI-MSI-edge ahci
     284 121748888  51769535    3822068   56924905    9232380  PCI-MSI-edge eth7a-fp-0
     294 116510649  15737953   28284037   41159203   31329456  PCI-MSI-edge eth7b-fp-0
     287 116074867   8853954   20284359   57160013   29776541  PCI-MSI-edge eth7a-fp-3
     298 112651243  33515406    5778308   22191092   51166437  PCI-MSI-edge eth7b-fp-4
     286 112159610   9427174    6496883   61879949   34355604  PCI-MSI-edge eth7a-fp-2
     301 110159560  26117566   21492156   17516565   45033273  PCI-MSI-edge eth7b-fp-7
     291 109723482  11233439   15504015   58302343   24683685  PCI-MSI-edge eth7a-fp-7
     290 109533013  25661958    8572641   10357938   64940476  PCI-MSI-edge eth7a-fp-6

