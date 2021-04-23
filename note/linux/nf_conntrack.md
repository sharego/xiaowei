

2020-12-17 域名故障，DNS解析失败，DNS主机`nf_conntrack table`表满验证与解决方案


# 一、验证现象
## 1.1 确认基本环境

1. 查看操作系统配置
```
sysctl -a | grep nf_conntrack_max
uname -a # 生产内核 4.9.127
```
2. 查看当前的nf_conntrack数
```
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/net/nf_conntrack | wc -l
cat /proc/sys/net/ipv4/netfilter/ip_conntrack_count
```

3. 准备测试机器软件

* client 主机 安装dnsdiag程序： `pip3 install dnsdiag`
* server 主机 安装 coredns:  `wget https://github.com/coredns/coredns/releases/download/v1.8.0/coredns_1.8.0_linux_amd64.tgz`

## 1.2 调整参数，模拟测试
1. 先查看当前值是多少，设置为一个相对较小的数，测试容易达到
```
sysctl -w net.netfilter.nf_conntrack_max=15
```

2. 在server上启动coredns服务
> 注意关闭 dnsmasq和53端口监听情况

server执行: `./coredns`

3. 客户端进行模拟dns请求
client: `dnsping -c 200 -s 10.211.55.29 baidu.com`

4. 测试期间观察
* server: 观察 nf_conntrack_count 数上升，并达到上限, `watch -n1 cat /proc/sys/net/netfilter/nf_conntrack_count` 和 内核日志信息 `dmesg | grep conntrack` 可以看到`nf_conntrack: nf_conntrack: table full, dropping packet`错误信息
* client: 观察到 偶发性`request timeout`，如下图：
![https://xw9.oss-cn-beijing.aliyuncs.com/img/cs/nfconntrack-201218a.png](https://xw9.oss-cn-beijing.aliyuncs.com/img/cs/nfconntrack-201218a.png)

## 1.3 结论：
> nf_conntrack 表满，将导致dns请求包被丢弃，从而体现为dns解析超时，导致dns域名解析失败

# 二、解决方案

## 2.1 方法一
彻底关闭nf_conntrack, 即关闭该内核模块。docker运行，会自动加载该模块，在docker环境上不推荐

## 2.2 方法二
针对具体端口，设置 NOTRACK, 以默认DNS 53端口为例（具体生产端口已生产配置为准），

命令行下执行如下命令：
```
iptables -t raw -A PREROUTING -p tcp --dport 53 -j NOTRACK
iptables -t raw -A PREROUTING -p udp --dport 53 -j NOTRACK
iptables -t raw -A PREROUTING -p tcp --sport 53 -j NOTRACK
iptables -t raw -A PREROUTING -p udp --sport 53 -j NOTRACK
iptables -t raw -A OUTPUT -p tcp --sport 53 -j NOTRACK
iptables -t raw -A OUTPUT -p udp --sport 53 -j NOTRACK
iptables -t raw -A OUTPUT -p tcp --dport 53 -j NOTRACK
iptables -t raw -A OUTPUT -p udp --dport 53 -j NOTRACK

#
iptables -I INPUT  -p udp -m udp --sport 53 -j ACCEPT
iptables -I INPUT  -p udp -m udp --dport 53 -j ACCEPT
```

注意上述命令仅在内存生效，主机重启或iptables服务重启后就没有了。 对于centos7及以上，需要配置到 `/etc/sysconfig/iptables` 中, 配置内容如下。注意，**如果filter存在，把udp 53的相关配置添加在最前面**, 文件内容编辑后，需要重启`iptables`服务，注意设置该服务开机启动：
```
*raw
:PREROUTING ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 53 -j NOTRACK
-A PREROUTING -p udp -m udp --dport 53 -j NOTRACK
-A PREROUTING -p tcp -m tcp --sport 53 -j NOTRACK
-A PREROUTING -p udp -m udp --sport 53 -j NOTRACK
-A OUTPUT -p tcp -m tcp --sport 53 -j NOTRACK
-A OUTPUT -p udp -m udp --sport 53 -j NOTRACK
-A OUTPUT -p tcp -m tcp --dport 53 -j NOTRACK
-A OUTPUT -p udp -m udp --dport 53 -j NOTRACK
COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -p udp -m udp --dport 53 -j ACCEPT
-A INPUT -p udp -m udp --sport 53 -j ACCEPT
COMMIT
```

配置并重启服务后，执行如下命令，均可以看到53端口:
```
iptables -nL -t raw
iptables -nL -t filter
```

## 2.3 方法三

将`nf_conntrack_max`值改大，具体大小需要根据网络并发请求量进行计算:
```
# vim /etc/sysctl.conf
# 添加或修改 net.netfilter.nf_conntrack_max=
# 生效
sysctl -p
```

# 三、生产操作

1. 使用方法二，直接设置生产使用的dns端口为notrack，并同时在filter表中，允许该端口通过访问
2. 测试重启主机，验证重启后iptables规则自动加载正确，规则存在,coredns服务正常
3. **先配置测试环境，后上线生产**，小心操作iptables！！
