
关于 net.ipv4.tcp_timestamps 内核参数：

1. 启动该参数将在tcp的数据包中设置时间戳的值，并激活RTTM（Round Trip Time Measurement）和PAWS（Protect Against Wrapped Sequences <TCP序号循环重复问题>）机制
    1. RTTM 可以更精确的计算RTT（TCP包中包含时间戳了）
    1. 禁用tcp_timestamps将禁用RTTM和PAWS
    1. 启用有部分安全漏洞风险,该风险RHEL8中通过`jiffies`初始化机制已解决
    1. 需要注意该参数与`net.ipv4.tcp_tw_recycle`、`net.ipv4.tcp_tw_reuse` 联合作用的场景
    1. `net.ipv4.tcp_tw_reuse` 启用 则内核可以继续使用`TIME-WAIT`状态下的`sockets`，该参数不推荐启用，避免TCP实现不兼容的问题, 启用前先测试, 该参数rhel默认不启用
    1. `tcp_tw_reuse` 参数启用，应该同时启用`tcp_timestamps`
    1. `net.ipv4.tcp_tw_recycle` 启用 可以快速回收`TIME-WAIT`状态的`sockets`，该参数默认不启用，也没有太大的用处，尤其是`Load Balancing`场景可能有问题，可用`net.ipv4.tcp_tw_reuse`替代
    1. `net.ipv4.tcp_tw_recycle` 启用时，应该启用`tcp_timestamps`, 否则可能导致`SYN`包被忽略
1. RHEL默认启用该参数，即`net.ipv4.tcp_timestamps = 1`，一般不推荐禁用该参数
1. 大多数场景下启用该参数提升网络性能（通过精确计算RTT），增加的计算量较小，计算成本较低
1. timestamps参数需要client与server两端`同时`启用才能生效，只要任意一方是禁用则该功能特性无法启用
1. 禁用后，缺乏PAWS，对于快速网络重连场景存在网络延迟风险
1. 在`NAT`网络场景下使用时应该`禁用`该参数，不兼容，启用可能导致`SYN`包被丢弃
1. 禁用该参数一般设置文件 `/etc/sysctl.d/net.conf` 中 `net.ipv4.tcp_timestamps = 0` 或 内核即时修改启用 `sysctl -w net.ipv4.tcp_timestamps=1` 或 `echo 1 > /proc/sys/net/ipv4/tcp_timestamps`
1. 网上博客：[TCP timestamp](http://perthcharles.github.io/2015/08/27/timestamp-intro/)
1. 详细规范文件: [RFC132](https://www.ietf.org/rfc/rfc1323.txt), 该RFC是TCP高性能的扩展, 最新版本是[RFC7323](https://tools.ietf.org/rfc/rfc7323.txt)
