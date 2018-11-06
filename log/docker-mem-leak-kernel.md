## 测试目的
验证docker在低版本内核上因内存隔离造成的内存泄漏，参考资料
- [kubernetes 1.9 与 CentOS 7.3 内核兼容问题](http://www.linuxfly.org/kubernetes-19-conflict-with-centos7/)
- [一行 kubernetes 1.9 代码引发的血案（与 CentOS 7.x 内核兼容性问题）](http://dockone.io/article/4797)
- [Docker leaking cgroups causing no space left on device?](https://github.com/moby/moby/issues/29638)
- [application crash due to k8s 1.9.x open the kernel memory accounting by default](https://github.com/kubernetes/kubernetes/issues/61937)

## 主机环境
8c 16g (内存至少8g) centos74 

## 测试准备
1 安装Docker
```bash
yum install -y yum-utils epel-release wget
wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# 查找所有可用版本docker，并安装指定版本
yum -y install docker-ce-17.06.2.ce-1.el7.centos.x86_64
mkdir /etc/docker
#配置仓库镜像
cat > /etc/docker/daemon.json << EOF
{
    "registry-mirrors":["https://registry.docker-cn.com"]
}
EOF
```
systemctl start docker
systemctl enable docker
docker pull nginx

2 安装高版本内核
```bash
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
yum --disablerepo=\* --enablerepo=elrepo-kernel repolist
yum --disablerepo=\* --enablerepo=elrepo-kernel list kernel*
yum --disablerepo=\* --enablerepo=elrepo-kernel install -y kernel-lt.x86_64
yum --disablerepo=\* --enablerepo=elrepo-kernel install -y kernel-ml.x86_64
```
>[root@10-255-0-139 ~]# grep menuentry.*Core /etc/grub2.cfg 
menuentry 'CentOS Linux (4.18.12-1.el7.elrepo.x86_64) 7 (Core)' --class centos --class gnu-linux --class gnu --class os --unrestricted $menuentry_id_option 'gnulinux-4.18.12-1.el7.elrepo.x86_64-advanced-29342a0b-e20f-4676-9ecf-dfdf02ef6683' {
menuentry 'CentOS Linux (4.4.159-1.el7.elrepo.x86_64) 7 (Core)' --class centos --class gnu-linux --class gnu --class os --unrestricted $menuentry_id_option 'gnulinux-4.4.159-1.el7.elrepo.x86_64-advanced-29342a0b-e20f-4676-9ecf-dfdf02ef6683' {
menuentry 'CentOS Linux (3.10.0-693.21.1.el7.x86_64) 7 (Core)' --class centos --class gnu-linux --class gnu --class os --unrestricted $menuentry_id_option 'gnulinux-3.10.0-693.21.1.el7.x86_64-advanced-29342a0b-e20f-4676-9ecf-dfdf02ef6683' {
menuentry 'CentOS Linux (0-rescue-8bd05758fdfc1903174c9fcaf82b71ca) 7 (Core)' --class centos --class gnu-linux --class gnu --class os --unrestricted $menuentry_id_option 'gnulinux-0-rescue-8bd05758fdfc1903174c9fcaf82b71ca-advanced-29342a0b-e20f-4676-9ecf-dfdf02ef6683' {

## 测试过程记录

### 测试脚本
```bash
# 清理所有遗留docker容器
docker rm -f $(docker ps -aq)
# 消耗所有cgroup
mkdir /sys/fs/cgroup/memory/test
for i in `seq 1 65535`;do mkdir /sys/fs/cgroup/memory/test/test-${i} || break; done
# 释放2个cgroup来创建容器(1个给容器,1个docker初始化)
rmdir /sys/fs/cgroup/memory/test/test-xxx
rmdir /sys/fs/cgroup/memory/test/test-xxx
# 循环创建删除无内存限制和有内存限制的容器
docker run -id nginx
docker run -id -m100m nginx
```

### 内核3.10.0-693.21.1
> [root@10-255-0-139 ~]# mkdir /sys/fs/cgroup/memory/test
[root@10-255-0-139 ~]# for i in `seq 1 65535`;do mkdir /sys/fs/cgroup/memory/test/test-${i} || break; done
mkdir: cannot create directory ‘/sys/fs/cgroup/memory/test/test-65487’: No space left on device
[root@10-255-0-139 ~]# cat /proc/cgroups 
#subsys_name	hierarchy	num_cgroups	enabled
cpuset	9	1	1
cpu	8	49	1
cpuacct	8	49	1
memory	7	65535	1
devices	11	48	1
freezer	4	1	1
net_cls	2	1	1
blkio	5	48	1
perf_event	6	1	1
hugetlb	10	1	1
pids	3	48	1
net_prio	2	1	1

创建docker容器测试内存

case1 没有cgroup,创建失败
>[root@10-255-0-139 ~]# docker run -id nginx
baf17c12eb765214b490ffa7a2e3fe0836a40991f9dc8f2a0b0842aaa4cf2e30
docker: Error response from daemon: oci runtime error: container_linux.go:262: starting container process caused "process_linux.go:261: applying cgroup configuration for process caused \"mkdir /sys/fs/cgroup/memory/docker: no space left on device\"".

case2 删除cgroup, 循环创建删除容器
>[root@10-255-0-139 ~]# docker run -id nginx
7a1076a7ec5a6874bf5fe699ddaca472f592003ab31f6816f2afa82470d41241
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker rm -f 7a107
7a107
[root@10-255-0-139 ~]# docker run -id nginx
1ac569dd25efea1929e734a6379b83360b0da4a45511b203b917b2658eb3ed51
[root@10-255-0-139 ~]# docker rm -f 1ac
1ac

case3 循环创建删除限制内存大小的容器
>[root@10-255-0-139 ~]# docker run -id -m 100m nginx
eba25b6387c2181aaf38cbef87fce73a7707ca61df9a5f03326f4d94a418b751
[root@10-255-0-139 ~]# docker rm -f eba
eba
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker run -id -m 100m nginx
a82b247f73e4626d7ccf9db32505ff5ed88fe16c745eda4015f08b596d366f21
docker: Error response from daemon: oci runtime error: container_linux.go:262: starting container process caused "process_linux.go:261: applying cgroup configuration for process caused \"mkdir /sys/fs/cgroup/memory/docker/a82b247f73e4626d7ccf9db32505ff5ed88fe16c745eda4015f08b596d366f21: no space left on device\"".
[root@10-255-0-139 ~]# cat /proc/cgroups 
#subsys_name	hierarchy	num_cgroups	enabled
cpuset	9	2	1
cpu	8	50	1
cpuacct	8	50	1
memory	7	65534	1
devices	11	49	1
freezer	4	2	1
net_cls	2	2	1
blkio	5	49	1
perf_event	6	2	1
hugetlb	10	2	1
pids	3	49	1
net_prio	2	2	1
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker run -id nginx
f256417fd50bde636d65b66d8f05f35fa19416483197a81f027ce077abd10469
docker: Error response from daemon: oci runtime error: container_linux.go:262: starting container process caused "process_linux.go:261: applying cgroup configuration for process caused \"mkdir /sys/fs/cgroup/memory/docker/f256417fd50bde636d65b66d8f05f35fa19416483197a81f027ce077abd10469: no space left on device\"".

### 内核4.18.12-1

>[root@10-255-0-139 ~]# mkdir /sys/fs/cgroup/memory/test
[root@10-255-0-139 ~]# for i in `seq 1 65535`;do mkdir /sys/fs/cgroup/memory/test/test-${i} || break; done
mkdir: cannot create directory ‘/sys/fs/cgroup/memory/test/test-65485’: Cannot allocate memory
[root@10-255-0-139 ~]# cat /proc/cgroups 
#subsys_name	hierarchy	num_cgroups	enabled
cpuset	4	1	1
cpu	5	50	1
cpuacct	5	50	1
blkio	12	72	1
memory	8	65557	1
devices	7	49	1
freezer	10	1	1
net_cls	6	1	1
perf_event	9	1	1
net_prio	6	1	1
hugetlb	2	1	1
pids	3	49	1
rdma	11	1	1

case4 测试容器创建和删除
>[root@10-255-0-139 ~]# docker run -id nginx
c89a0a5d22e85646c0b42971c11c12569f61ea872ee18c2fdf21093f33f56113
[root@10-255-0-139 ~]# docker rm -f c89
c89
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker run -id nginx
22b8ca356c48db086772c7641800760a4b3594d2ff0d534c02025d821a53ef54
[root@10-255-0-139 ~]# docker rm -f 22b8
22b8
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker run -id -m100m nginx
201bfed915b99a4f277261cef2794d3a1e97f4b21a56d94d5fe3526f3554bd7a
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker rm -f 201
201
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker run -id -m100m nginx
86a43390852dd072b5a0b8347c93db183602c4005009fa4d4a7ecd039b8aa679
[root@10-255-0-139 ~]# docker rm -f 86a
86a
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker run -id -m100m nginx
9f23dbd2b513ff62aa264cffe384847be40c17f32cd81327502081d93f6e5d4a
[root@10-255-0-139 ~]# docker rm -f 9f23
9f23

### 内核4.4.159-1.el7

>[root@10-255-0-139 ~]# docker run -id nginx
0347b7c769a4d776ef249c592df01b5914adac42e610da6d1cda4d8af9bf7c26
[root@10-255-0-139 ~]# docker rm -f 034
034
[root@10-255-0-139 ~]# docker run -id nginx
f4270db391f6d616be7667ebb239b36b52b04fb5cee4973c6a56e5f222bec41d
[root@10-255-0-139 ~]# docker rm -f f427
f427
[root@10-255-0-139 ~]# docker run -id nginx
a0b01c6e3805e26b3c7eb8e45834f94f7a229b7fbfc34841895baaae0090050c
[root@10-255-0-139 ~]# docker rm -f a0b
a0b
[root@10-255-0-139 ~]# docker run -id -m 100m nginx
0fac1624d5787e141f3eacc8036f5c630f5b575cb28ad97a476cdb0f0491a216
[root@10-255-0-139 ~]# docker rm -f 0fac
0fac
[root@10-255-0-139 ~]# docker run -id -m 100m nginx
f43ddc7f6505641e3cc1e11367184447cbb08874729aaf7841fcff5d1eb41449
[root@10-255-0-139 ~]# docker rm -f f43
f43
[root@10-255-0-139 ~]# docker run -id -m 100m nginx
322d9ecb78b0931bf7546507af9fed2a8bf3fc5d3ce2c776759888dcd5dd5f06
[root@10-255-0-139 ~]# docker rm -f 322
322
[root@10-255-0-139 ~]# 
[root@10-255-0-139 ~]# docker run -id -m 100m nginx
938920a13fcf6525fec74285520b1f2ea207e22bb8d11f4f007778bea8ab1d7d
[root@10-255-0-139 ~]# docker run -id -m 100m nginx
9547ce22041e062c4847d1ce2353af40b93f2899ca7b3034f76d909524c3c94b
docker: Error response from daemon: oci runtime error: container_linux.go:262: starting container process caused "process_linux.go:261: applying cgroup configuration for process caused \"mkdir /sys/fs/cgroup/memory/docker/9547ce22041e062c4847d1ce2353af40b93f2899ca7b3034f76d909524c3c94b: cannot allocate memory\"".


## 测试结论
1. 复现docker容器创建失败场景,证明内存限制导致cgroup内存泄漏
2. 4.4及4.18内核无此问题

## 疑问
不同内核版本的最大num_cgroups数不一致
