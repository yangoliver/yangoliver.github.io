---
layout: post
title: Linux Crash Utility - coding notes
categories:
- English
tags:
- [crash]
---


1. Where could I found coding exmaples?

    See [crash whitepaper](http://people.redhat.com/anderson/crash_whitepaper), **Command Extensions** section.

2. Public APIs defined in defs.h

    Crash public APIs are defined in defs.h. 
    
    * Don not change existing APIs in defs.h
    * The code changes in defs.h should not break the 3rd party crash extension source code build
    * If changes can be put into private files, don not change in defs.h
    * Make code changes in defs.h as simple as possible.

3. Other coding and testing guidelines

    * Run "make warn" to fix all warnings.
    
    * It would be better, if variables, APIs, and CLI output naming could relect kernel data structure naming.
    
    * CLI changes should also add man page changes in help.c
    
    * Test must be done on both 32 and 64 bit kernels
    
    * Per your code changes, need to consider the test on different kernel versions
    
    * If you don not have enough test resources, please discuss with maintainer to leverage community test resources.

	* Before sending out the patch, please make sure your changes is on top of latest upstream patch

4. Build and test environment setup

    Make sure you had installed following packages. I used Fedora CLIs as exmaples.

    * Basic development tools

          sudo yum -y groupinstall "Development Tools"
    
    * patch

          sudo yum install -y patch
    
    * ncurses-devel 

          sudo yum install -y ncurses-devel 
    
    * zlib-devel
    
          sudo yum install -y zlib-devel
    
    * bison and byacc
    
          yum install -y bison 
          yum install –y byacc
    
    * kernel debug info packages, if required. 

	  for 64 bit x86 kernel, 
    
          debuginfo-install kernel
		  
	  for 32 bit x86 kernel,

          debuginfo-install kernel-PAE
