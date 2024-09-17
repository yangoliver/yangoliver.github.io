---
layout: post
title: OpenSolaris - my patches
description: This page is used to hold Oliver Yang's OpenSolaris patch while he was working for SUN & Oracle.
categories: [English, Software, Career]
tags: [kernel, solaris]
---

>The content reuse need include the original link: <http://oliveryang.net>

* content
{:toc}

This page is for tracking my patches for [OpenSolaris](https://en.wikipedia.org/wiki/OpenSolaris). As you may already know,
Oracle had closed OpenSolaris project after it acquired Sun Microsystem in 2009.
For this reason, all my patches below have been found and referred from [Illumos Github Repository](https://github.com/illumos/illumos-gate).
The [Illumos](https://en.wikipedia.org/wiki/Illumos) is a fork of OpenSolaris, and the code changes after Oracle & SUN merge have never been available in Illumos.

For above reasons, it was quite difficult to find all my footprints in Illumos code base. While reviewing the source code of Solaris, it always made me recall the days I worked for Solaris.

## 1. Solaris IO Subsystem

### 1.1 SRIOV Project

- [New Feature: Inter-Domain communication among LDOM and Xen VMs](https://github.com/illumos/illumos-gate/blob/master/usr/src/uts/common/io/pciex/pciev.c)

  Provided SRIOV devices PF/VF communication framework for PCIe config space emulation, PCIe UE & CE handling, other control commands transfers.

  Notes: My original commit logs were not imported in Illumos Git commit logs. I made 20000 lines of code changes in Solaris PCIe subsystem, which has both common module and Xen/LDOM specific modules.
         The `pciev.c` is one of source code file I introduced in my project. Only small part of them are opensourced. The remainning part was not opened becasue Oracle had stopped OpenSoalris Project.
         The [illumos-gate](https://github.com/illumos/illumos-gate) is based on [Illumos](https://en.wikipedia.org/wiki/Illumos), which is a fork of OpenSolaris.

### 1.2 Other Solaris IO subsystem RFEs & Bugfixes

The source code is not available in OpenSolaris code base.

## 2. NIC drivers


### 2.1 Intel Igb Driver

- [New Feature: Crossbow - Network Virtualization and Resource Management](https://github.com/illumos/illumos-gate/commit/da14cebe459d3275048785f25bd869cb09b5307f#diff-b862097351c2d196880a3750bbe1ccc0)

  Notes: In Solaris, big project was commited by gatekeeper (AKA. brach keeper in some other companies).
         I made the code changes under `usr/src/uts/common/io/igb/` directory, for enabling VMDq support in igb driver.

		 usr/src/uts/common/io/igb/igb.conf
		 usr/src/uts/common/io/igb/igb_gld.c
		 usr/src/uts/common/io/igb/igb_hw.h
		 usr/src/uts/common/io/igb/igb_main.c
		 usr/src/uts/common/io/igb/igb_osdep.c
		 usr/src/uts/common/io/igb/igb_osdep.h
		 usr/src/uts/common/io/igb/igb_rx.c
		 usr/src/uts/common/io/igb/igb_sw.h
		 usr/src/uts/common/io/igb/igb_tx.c

In 2008, I gave a presentation about my work on support VMDq feature in Soalris network virtualization project: Crossbow.
Please [download the slides here](https://github.com/yangoliver/mydoc/raw/master/share/nic_drivers_in_crossbow-v1.0.pdf)

### 2.2 Intel E1000g Driver

- [Perf tuning: 33X Tibco UDP and 20% ip forwarding perf boost](https://github.com/illumos/illumos-gate/commit/47b7744cbea59975a6b583125b7ed1ff2ac45313)

  This performance tuning work make me get the award from Intel OTC OpenSolaris team.

- [Bugfix: 6 bugfixes patch set for e1000g driver](https://github.com/illumos/illumos-gate/commit/4914a7d0d1ee59f8cc21b19bfd7979cb65681eac#diff-97109b3a307f7f937f934a7e517b0650)
- [Bugfix: e1000g panic bug under hotplug scenario](https://github.com/illumos/illumos-gate/commit/ea6b684a18957883cb91b3d22a9d989f986e5a32#diff-97109b3a307f7f937f934a7e517b0650)

Notes: The yy150190 was my SUN Employee ID, which could be found in OpenSolaris git/hg commit logs.
