---
layout: post
title: SMI link error
description: The article talks about what is the possible fault causes regarding to SMI link error.
categories: [English, Hardware]
tags:
- [hardware]
---

* content
{:toc}

>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

### 1. What is the SMI link?

SMI link is the Scalable Memory Interconnect communication channels between the Intel processor cores and main memory.

The topology of SMI link is,

	Core--->QPI bus--->iMC(Integrated Memory Controller)--->SMI link--->Scalable Memory Buffer--->DDR2/3/4 bus---> Memory DIMMs

### 2. How do we find SMI link error?

On Intel platform, it could be detected by BIOS SMI(System Management Interrupt) handler.
A SEL log could be found like below,

	9 | 06/28/2015 | 07:32:16 | SMI Link CRC Correctable Errors #0x0a | Persistent Parity Status | Asserted |  Memory_Slot=3 SMI_Link=1


### 3. What kind of actions should we take?

Replace the faulty hardware if we could see massive SMI link errors, even if the errors are correctable type.
If BIOS error handling could cannot locate exact error location, the fault components (FRU) could be,

* Memory DIMMs?

  Not sure, some high end platforms could know whether error is caused by link or ECC errors

* Memory risers

  Some high end platforms may have

* Mother board

  Due to faulty DIMM slots, Scalable Memory Buffer chipset

* CPU

  Faulty iMC

The hardware replacement work could be done per cost considerations.
