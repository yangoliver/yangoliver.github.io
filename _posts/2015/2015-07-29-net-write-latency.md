---
layout: post
title: Network write system call latency
description: An issue related to 2ms latency in 10G network. Using ftrace to diagnosis network latency problems.
categories:
- [English, Software]
tags:
- [network, perf, linux]
---

>This article was firstly published from <http://oliveryang.net>. The content reuse need include the original link.

Today, one guy told me he observed the write system call latency for 80 bytes write is about 2ms on a 10G network.
He suspected that this indicates some network latency problems.

Is he right?

The answer is no. At least, I am not sure. Depending on your workload.

I told him to capture the packets by the tools like tcpdump to confirm his suspects.
For network write system call, 2ms latency might not be quite bad.

### Why do I think 2ms write system call latency is not bad?

Because it is quite possible that write system call could be returned at millisecond level, but packet got sent out at
microsecond level.

In Linux network stack, under the write system call context, it could send the packets first, then got interrupted
by NIC driver RX interrupts, and run into packets receive loop. Especially, when write code put the packets to NIC,
it disabled interrupts in that period. That means, after interrupt got enabled, it would cause the interrupts got fired
immediately if any IRQs were bound to this CPU.

If the system is under heavy network traffic, the ```net_rx_action``` code actually allows polling loop for more than
2 jiffies, which is actually 2ms.

	static void net_rx_action(struct softirq_action *h)
	{
		struct softnet_data *sd = this_cpu_ptr(&softnet_data);
		unsigned long time_limit = jiffies + 2;
		int budget = netdev_budget;
		LIST_HEAD(list);
		LIST_HEAD(repoll);

		local_irq_disable();
		list_splice_init(&sd->poll_list, &list);
		local_irq_enable();

		for (;;) {
			struct napi_struct *n;

			if (list_empty(&list)) {
				if (!sd_has_rps_ipi_waiting(sd) && list_empty(&repoll))
					return;
				break;
			}

			n = list_first_entry(&list, struct napi_struct, poll_list);
			budget -= napi_poll(n, &repoll);

			/* If softirq window is exhausted then punt.
			 * Allow this to run for 2 jiffies since which will allow
			 * an average latency of 1.5/HZ.
			 */
			if (unlikely(budget <= 0 ||
				     time_after_eq(jiffies, time_limit))) { // time limitation check, break if more than 2ms
				sd->time_squeeze++;
				break;
			}
		}

		[...........snipped..........]

	}


In fact, in latest kernel ```__do_softirq``` has the similar logic to limit the soft_irq loop by both
```MAX_SOFTIRQ_RESTART``` and 2 jiffies time limitations.

Anyway, today's Linux interrupt context, the latency could be many milliseconds.

For this reason it is quite possible that the packet is sent by write system call first at us speed.
But after that, write system call continue to receive the packets, and run into longer loop for packets RX handling.

Just few times of 2ms latency is not a problem. What if he saw average write system call latency is 2ms?

It is hard to say. His testing is a system wide testing, which will not only stress network stack, bust also stress
file system and storage IO stack. That means, if write system call got pinned by the interrupts not related to
network workload, he can also see this issue. In this case, it is not network problem.


### How does the code path look like?

Linux provides the rich set of dynamic tracing tools to allow us to learn kernel code path.

In this case, I used [funcgraph](https://github.com/brendangregg/perf-tools/blob/master/examples/funcgraph_example.txt),
which is a shell scripts based on Linux Ftrace tool.

From the output, we can see in do_sync_write code path, after the packets got sent, it started to receive packet. 
At the end of rx code path, it calls into ```ep_poll_callback``` to notify the data is ready.

This is a not a very busy system, but the do_sync_write took more than 82us to return.

	# ./funcgraph -d 1 do_sync_write

		Tracing "do_sync_write" for 1 seconds...
		 13)               |  do_sync_write() {
		 13)               |    sock_aio_write() {
		 13)               |      inet_sendmsg() {
		 13)               |        tcp_sendmsg() {
		 13)               |          lock_sock_nested() {
		 13)               |            _raw_spin_lock_bh() {
		 13)   0.071 us    |              local_bh_disable();
		 13)   1.097 us    |            }
		 13)   0.136 us    |            _raw_spin_unlock();
		 13)   0.037 us    |            local_bh_enable();
		 13)   2.558 us    |          }
		 13)               |          tcp_send_mss() {
		 13)               |            tcp_current_mss() {
		 13)   0.202 us    |              ipv4_mtu();
		 13)               |              tcp_established_options() {
		 13)               |                tcp_v4_md5_lookup() {
		 13)   0.039 us    |                  tcp_v4_md5_do_lookup();
		 13)   0.357 us    |                }
		 13)   0.752 us    |              }
		 13)   1.962 us    |            }
		 13)   2.325 us    |          }
		 13)               |          sk_stream_alloc_skb() {
		 13)               |            __alloc_skb() {
		 13)   0.141 us    |              kmem_cache_alloc_node();
		 13)               |              __kmalloc_node_track_caller() {
		 13)   0.085 us    |                kmem_find_general_cachep();
		 13)   0.148 us    |                kmem_cache_alloc_node_trace();
		 13)   0.897 us    |              }
		 13)               |              ksize() {
		 13)   0.036 us    |                __phys_addr();
		 13)   0.583 us    |              }
		 13)   3.140 us    |            }
		 13)   3.615 us    |          }
		 13)               |          __tcp_push_pending_frames() {
		 13)               |            tcp_write_xmit() {
		 13)               |              tcp_init_tso_segs() {
		 13)   0.058 us    |                tcp_set_skb_tso_segs();
		 13)   0.451 us    |              }
		 13)               |              tcp_transmit_skb() {
		 13)               |                skb_clone() {
		 13)   0.098 us    |                  __copy_skb_header();
		 13)   0.609 us    |                }
		 13)               |                tcp_established_options() {
		 13)               |                  tcp_v4_md5_lookup() {
		 13)   0.039 us    |                    tcp_v4_md5_do_lookup();
		 13)   0.439 us    |                  }
		 13)   0.812 us    |                }
		 13)   0.043 us    |                skb_push();
		 13)   0.168 us    |                __tcp_select_window();
		 13)   0.186 us    |                tcp_options_write();
		 13)               |                tcp_v4_send_check() {
		 13)   0.207 us    |                  __tcp_v4_send_check();
		 13)   0.773 us    |                }
		 13)               |                ip_queue_xmit() {
		 13)               |                  __sk_dst_check() {
		 13)               |                    ipv4_dst_check() {
		 13)   0.079 us    |                      ipv4_validate_peer();
		 13)   0.461 us    |                    }
		 13)   0.883 us    |                  }
		 13)               |                  skb_dst_set_noref() {
		 13)   0.035 us    |                    debug_lockdep_rcu_enabled();
		 13)   0.462 us    |                  }
		 13)   0.049 us    |                  skb_push();
		 13)               |                  ip_local_out() {
		 13)               |                    __ip_local_out() {
		 13)   0.072 us    |                      debug_lockdep_rcu_enabled();
		 13)   0.543 us    |                    }
		 13)   0.036 us    |                    debug_lockdep_rcu_enabled();
		 13)               |                    ip_output() {
		 13)   0.042 us    |                      debug_lockdep_rcu_enabled();
		 13)               |                      ip_finish_output() {
		 13)   0.049 us    |                        debug_lockdep_rcu_enabled();
		 13)   0.049 us    |                        debug_lockdep_rcu_enabled();
		 13)   0.060 us    |                        ipv4_mtu();
		 13)   0.044 us    |                        debug_lockdep_rcu_enabled();
		 13)   0.045 us    |                        skb_push();
		 13)               |                        dev_queue_xmit() {
		 13)   0.035 us    |                          local_bh_disable();
		 13)               |                          dev_hard_start_xmit() {
		 13)               |                            netif_skb_features() {
		 13)   0.038 us    |                              harmonize_features();
		 13)   0.706 us    |                            }
		 13)               |                            loopback_xmit() {
		 13)   0.065 us    |                              sock_wfree();
		 13)   0.103 us    |                              eth_type_trans();
		 13)               |                              netif_rx() {
		 13)               |                                ktime_get_real() {
		 13)   0.054 us    |                                  getnstimeofday();
		 13)   0.419 us    |                                }
		 13)   0.079 us    |                                get_rps_cpu();
		 13)               |                                enqueue_to_backlog() {
		 13)   0.385 us    |                                  _raw_spin_lock();
		 13)   0.148 us    |                                  _raw_spin_unlock();
		 13)   1.251 us    |                                }
		 13)   3.116 us    |                              }
		 13)   4.452 us    |                            }
		 13)   6.336 us    |                          }
		 13)               |                          local_bh_enable() {
		 13)               |                            do_softirq() {
		 13)               |                              __do_softirq() {
		 13)   0.040 us    |                                msecs_to_jiffies();
		 13)               |                                net_rx_action() {
		 13)               |                                  process_backlog() {
		 13)   0.288 us    |                                    _raw_spin_lock();
		 13)   0.119 us    |                                    _raw_spin_unlock();
		 13)               |                                    __netif_receive_skb() {
		 13)               |                                      ip_rcv() {
		 13)               |                                        ip_rcv_finish() {
		 13)   0.035 us    |                                          debug_lockdep_rcu_enabled();
		 13)   0.036 us    |                                          debug_lockdep_rcu_enabled();
		 13)   0.035 us    |                                          debug_lockdep_rcu_enabled();
		 13)   0.035 us    |                                          debug_lockdep_rcu_enabled();
		 13)               |                                          ip_local_deliver() {
		 13)               |                                            ip_local_deliver_finish() {
		 13)   0.081 us    |                                              raw_local_deliver();
		 13)               |                                              tcp_v4_rcv() {
		 13)   0.037 us    |                                                debug_lockdep_rcu_enabled();
		 13)   0.036 us    |                                                debug_lockdep_rcu_enabled();
		 13)   0.385 us    |                                                __inet_lookup_established();
		 13)   0.219 us    |                                                sk_filter();
		 13)   0.425 us    |                                                _raw_spin_lock_nested();
		 13)               |                                                tcp_v4_do_rcv() {
		 13)   0.052 us    |                                                  tcp_v4_md5_do_lookup();
		 13)   0.048 us    |                                                  tcp_parse_md5sig_option();
		 13)               |                                                  tcp_rcv_established() {
		 13)   0.046 us    |                                                    tcp_parse_aligned_timestamp();
		 13)   0.049 us    |                                                    get_seconds();
		 13)   0.075 us    |                                                    tcp_rcv_rtt_update();
		 13)   0.459 us    |                                                    tcp_event_data_recv();
		 13)               |                                                    __tcp_ack_snd_check() {
		 13)               |                                                      tcp_send_delayed_ack() {
		 13)               |                                                        sk_reset_timer() {
		 13)               |                                                          mod_timer() {
		 13)               |                                                            lock_timer_base.clone.22() {
		 13)   0.275 us    |                                                              _raw_spin_lock_irqsave();
		 13)   0.628 us    |                                                            }
		 13)   0.060 us    |                                                            internal_add_timer();
		 13)   0.143 us    |                                                            _raw_spin_unlock_irqrestore();
		 13)   1.944 us    |                                                          }
		 13)   2.392 us    |                                                        }
		 13)   3.356 us    |                                                      }
		 13)   3.914 us    |                                                    }
		 13)               |                                                    sock_def_readable() {
		 13)               |                                                      __wake_up_sync_key() {
		 13)   0.242 us    |                                                        _raw_spin_lock_irqsave();
		 13)               |                                                        __wake_up_common() {
		 13)               |                                                          ep_poll_callback() {
		 13)   0.281 us    |                                                            _raw_spin_lock_irqsave();
		 13)               |                                                            __wake_up_locked() {
		 13)               |                                                              __wake_up_common() {
		 13)               |                                                                default_wake_function() {
		 13)               |                                                                  try_to_wake_up() {
		 13)   0.305 us    |                                                                    _raw_spin_lock_irqsave();
		 13)   0.093 us    |                                                                    task_waking_fair();
		 13)               |                                                                    select_task_rq_fair() {
		 13)   0.086 us    |                                                                      source_load();
		 13)   0.050 us    |                                                                      target_load();
		 13)   0.069 us    |                                                                      cpu_avg_load_per_task();
		 13)   0.070 us    |                                                                      idle_cpu();
		 13)   2.109 us    |                                                                    }
		 13)               |                                                                    native_smp_send_reschedule() {
		 13)               |                                                                      physflat_send_IPI_mask() {
		 13)   0.178 us    |                                                                        default_send_IPI_mask_sequence_phys();
		 13)   0.558 us    |                                                                      }
		 13)   0.966 us    |                                                                    }
		 13)   0.245 us    |                                                                    ttwu_stat();
		 13)   0.140 us    |                                                                    _raw_spin_unlock_irqrestore();
		 13)   6.722 us    |                                                                  }
		 13)   7.211 us    |                                                                }
		 13)   7.815 us    |                                                              }
		 13)   8.181 us    |                                                            }
		 13)   0.151 us    |                                                            _raw_spin_unlock_irqrestore();
		 13)   9.762 us    |                                                          }
		 13) + 10.294 us   |                                                        }
		 13)   0.153 us    |                                                        _raw_spin_unlock_irqrestore();
		 13) + 11.824 us   |                                                      }
		 13) + 12.431 us   |                                                    }
		 13) + 20.877 us   |                                                  }
		 13) + 22.064 us   |                                                }
		 13)   0.123 us    |                                                _raw_spin_unlock();
		 13) + 25.964 us   |                                              }
		 13) + 26.968 us   |                                            }
		 13) + 27.379 us   |                                          }
		 13) + 29.442 us   |                                        }
		 13) + 29.913 us   |                                      }
		 13) + 30.701 us   |                                    }
		 13) + 32.114 us   |                                  }
		 13)   0.048 us    |                                  net_rps_action_and_irq_enable.clone.45();
		 13) + 33.281 us   |                                }
		 13)   0.036 us    |                                rcu_bh_qs();
		 13)   0.040 us    |                                __local_bh_enable();
		 13) + 35.347 us   |                              }
		 13) + 35.732 us   |                            }
		 13) + 36.233 us   |                          }
		 13) + 44.380 us   |                        }
		 13) + 47.394 us   |                      }
		 13) + 48.493 us   |                    }
		 13) + 50.743 us   |                  }
		 13) + 54.129 us   |                }
		 13) + 60.178 us   |              }
		 13)               |              tcp_event_new_data_sent() {
		 13)               |                sk_reset_timer() {
		 13)               |                  mod_timer() {
		 13)               |                    lock_timer_base.clone.22() {
		 13)   0.213 us    |                      _raw_spin_lock_irqsave();
		 13)   0.607 us    |                    }
		 13)   0.057 us    |                    internal_add_timer();
		 13)   0.138 us    |                    _raw_spin_unlock_irqrestore();
		 13)   1.998 us    |                  }
		 13)   2.408 us    |                }
		 13)   2.884 us    |              }
		 13) + 65.221 us   |            }
		 13) + 65.802 us   |          }
		 13)               |          release_sock() {
		 13)               |            _raw_spin_lock_bh() {
		 13)   0.037 us    |              local_bh_disable();
		 13)   0.643 us    |            }
		 13)               |            _raw_spin_unlock_bh() {
		 13)   0.049 us    |              local_bh_enable_ip();
		 13)   0.561 us    |            }
		 13)   2.114 us    |          }
		 13) + 79.729 us   |        }
		 13) + 80.595 us   |      }
		 13) + 81.506 us   |    }
		 13) + 82.396 us   |  }
