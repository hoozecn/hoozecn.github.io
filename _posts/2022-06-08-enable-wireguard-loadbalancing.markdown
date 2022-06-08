---
layout: post
title:  "wireguard 的高可用配置"
date: 2022-06-08 00:00:00
categories: tech
tags: network wireguard high-availability
---

# 背景

使用 [Wireguard](https://www.wireguard.com/) 技术, 可以很方便的在多云环境中做网络互连. 我们通常为每个 VPC 下配置一台 [wireguard 网关](https://tailscale.com/blog/how-tailscale-works/#hub-and-spoke-networks) 做为该 VPC 的流量出入口.

如果网关服务器挂了, 所在的 VPC 就 GG 了. 那么如何对它的服务端做高可用配置呢? 参考 [HIGH AVAILABILITY WIREGUARD ON AWS](https://www.procustodibus.com/blog/2021/02/ha-wireguard-on-aws/) 这篇文章, 笔者在本地环境中使用 ipvs 模拟了一把, 希望能对有兴趣的同学有一些启发.

# 准备工作

本地实验环境的 vm 规划如下

|hostname|private ip|wireguard ip|
|---|---|---|
|wg-gateway-01|10.211.55.118|10.255.0.1|
|wg-gateway-02|10.211.55.119|10.255.0.1|
|wg-lb|10.211.55.120|-|
|wg-client-0|10.211.55.121|10.255.0.2|
|wg-client-1|10.211.55.122|10.255.0.3|

其中, wg-gateway-01 和 wg-gateway-02 具有完全相同的 wg 配置, 作为网关的后端节点. wg-lb 是网关的前端节点, 具有虚拟 IP 172.16.0.1. wg-client-0, wg-client-1 为两个 wg 客户端.

# 具体配置如

在安装必要的组件 wireguard-tools, ipvsadm 等后, 每台机器的配置如下. 配置完成后启动相应的服务.

`[wg-gateway-01 ~] cat /etc/wireguard/wg0.conf`

```
[Interface]
Address = 10.255.0.1
ListenPort = 51280
PrivateKey = iIltY+VwAqbJGHKExoBX9SU6M5u4RGDoGEYFHA1Ey0E=
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
AllowedIPs = 10.255.0.2
PublicKey = EDkM4PCmyhSb1MWLbXe35WwLcPDdlUlA3lEVhaO520U=
PersistentKeepalive = 15

[Peer]
AllowedIPs = 10.255.0.3
PublicKey = Y4th19122MQrsOSBm3J30/RccyT7RpLHyQFfnVfRPwA=
PersistentKeepalive = 15
```

`[root@wg-gateway-02 ~] cat /etc/wireguard/wg0.conf`

```
[Interface]
Address = 10.255.0.1
ListenPort = 51280
PrivateKey = iIltY+VwAqbJGHKExoBX9SU6M5u4RGDoGEYFHA1Ey0E=
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
AllowedIPs = 10.255.0.2
PublicKey = EDkM4PCmyhSb1MWLbXe35WwLcPDdlUlA3lEVhaO520U=
PersistentKeepalive = 15

[Peer]
AllowedIPs = 10.255.0.3
PublicKey = Y4th19122MQrsOSBm3J30/RccyT7RpLHyQFfnVfRPwA=
PersistentKeepalive = 15
```

`[root@wg-client-01 ~] /etc/wireguard/wg0.conf`

```
[Interface]
Address = 10.255.0.2
ListenPort = 51280
PrivateKey = CMN+6nYc3fGcFcJWOuwAd1lCtQlizqE0Y3n0OEVFkVA=
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
AllowedIPs = 10.255.0.1
Endpoint = 172.16.0.1:51280
PublicKey = jSH4m9Uu5FpLkKA5G8gTG0XWPGkqIUkGTsxv7rMniXk=
PersistentKeepalive = 15
```

`[root@wg-client-01 ~] cat /etc/wireguard/wg0.conf  && ip route`

```
[Interface]
Address = 10.255.0.2
ListenPort = 51280
PrivateKey = CMN+6nYc3fGcFcJWOuwAd1lCtQlizqE0Y3n0OEVFkVA=
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
AllowedIPs = 10.255.0.1
Endpoint = 172.16.0.1:51280
PublicKey = jSH4m9Uu5FpLkKA5G8gTG0XWPGkqIUkGTsxv7rMniXk=
PersistentKeepalive = 15

default via 10.211.55.1 dev eth0 proto dhcp metric 100
10.211.55.0/24 dev eth0 proto kernel scope link src 10.211.55.121 metric 100
10.255.0.1 dev wg0 scope link
172.16.0.1 via 10.211.55.120 dev eth0
```

`[root@wg-client-02 ~]# cat /etc/wireguard/wg0.conf && ip route`

```
[Interface]
Address = 10.255.0.3
ListenPort = 51280
PrivateKey = ENTaxloTXHeVJy1Mry0rrFb9ReFg/mkq39iLh4vIOG8=
PostUp   = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
AllowedIPs = 10.255.0.1
Endpoint = 172.16.0.1:51280
PublicKey = jSH4m9Uu5FpLkKA5G8gTG0XWPGkqIUkGTsxv7rMniXk=
PersistentKeepalive = 15

default via 10.211.55.1 dev eth0 proto dhcp metric 100
10.211.55.0/24 dev eth0 proto kernel scope link src 10.211.55.121 metric 100
10.255.0.1 dev wg0 scope link
172.16.0.1 via 10.211.55.120 dev eth0
```

`[root@wg-lb ~]# ipvsadm -l -n && sysctl -a|grep ipv4.ip_forward|ip addr show lo`

```
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
UDP  172.16.0.1:51280 sh
  -> 10.211.55.118:51280          Masq    1      0          0
  -> 10.211.55.119:51280          Masq    1      0          0
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet 172.16.0.1/32 scope global lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
```

从上面的配置需要注意的是, wg-lb 中需要把  172.16.0.1 加入到回环接口 lo 中, virtual service 的 lb 规则为 sh 即 [Source Hashing](http://kb.linuxvirtualserver.org/wiki/Source_Hashing_Scheduling), 即 需要保持 wireguard 的 session.


# 测试

从 wg-client-01 ping 10.255.0.1, 可以在 wg-gateway-02 上抓到 icmp 包

```
[root@wg-gateway-01 ~]# tcpdump -i wg0 icmp -n
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on wg0, link-type RAW (Raw IP), capture size 262144 bytes
12:06:19.304274 IP 10.255.0.2 > 10.255.0.1: ICMP echo request, id 1452, seq 32, length 64
12:06:19.304307 IP 10.255.0.1 > 10.255.0.2: ICMP echo reply, id 1452, seq 32, length 64
12:06:20.233486 IP 10.255.0.2 > 10.255.0.1: ICMP echo request, id 1452, seq 33, length 64
12:06:20.233527 IP 10.255.0.1 > 10.255.0.2: ICMP echo reply, id 1452, seq 33, length 64
```

从 wg-client-02 ping 10.255.0.1, 可以在 wg-gateway-02 上抓到 icmp 包

```
[root@ wg-gateway-02 ~]# tcpdump -i wg0 icmp -n
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on wg0, link-type RAW (Raw IP), capture size 262144 bytes
12:08:20.106809 IP 10.255.0.3 > 10.255.0.1: ICMP echo request, id 1444, seq 11, length 64
12:08:20.106889 IP 10.255.0.1 > 10.255.0.3: ICMP echo reply, id 1444, seq 11, length 64
12:08:21.121003 IP 10.255.0.3 > 10.255.0.1: ICMP echo request, id 1444, seq 12, length 64
12:08:21.121033 IP 10.255.0.1 > 10.255.0.3: ICMP echo reply, id 1444, seq 12, length 64
```

# 总结

在云上的情况, 我们可以使用云厂商提供的负载均衡替代 wg-lb 来实现 wireguard 网关的高可用.