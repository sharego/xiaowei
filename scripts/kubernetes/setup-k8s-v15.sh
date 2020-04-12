#!/bin/bash

#author: xiaowei

# Ref: https://v1-15.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm

## close os swap

swapoff -a
sudo su - root -c 'echo 0 > /proc/sys/vm/swappiness'
sed -i '/ swap /s/^/#/g' /etc/fstab

## set sysctl

# prepare
yum -y install docker-ce ipvsadm

## add ipvs modules

cat <<EOF > /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
ipvs_modules="ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4"
for kernel_module in \${ipvs_modules}; do
    /sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
    if [ \$? -eq 0 ]; then
        /sbin/modprobe \${kernel_module}
    fi
done
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules

# 立即执行加载（上述文件可开机自动加载）
bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep ip_vs

## add aliyun kubernetes repo
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

yum --disablerepo=\* --enablerepo=kubernetes search --showduplicates kubeadm # 执行导入gpg key

# 安装 1.15.3 版本
# yum install -y --disableexcludes=kubernetes kubeadm-1.15.3

export k8ver=1.15.3
yum install -y --disableexcludes=kubernetes kubeadm-$k8ver kubelet-$k8ver kubectl-$k8ver

## configuration file

### according https://kubernetes.io/docs/setup/best-practices/cluster-large/
### most of 150000 total pods on 5000 nodes

cat <<EOF > kubeadmin-init.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.15.3
clusterName: k8s-xiaowei
dns:
  type: CoreDNS
networking:
  podSubnet: 192.168.0.0/16 # pod网络的网段,cluser-cidr
  # serviceSubnet: 10.116.0.0/14 # service 网络网段 默认 10.96.0.0/12
imageRepository: gcr.azk8s.cn/google-containers # image的仓库源
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
EOF

# 只拉取镜像
# kubeadm config images pull --config kubeadm-init.yaml
# 列举镜像列表
# kubeadm config --kubernetes-version=v$k8ver --image-repository=gcr.azk8s.cn/google-containers images list

## use command line configuration
### service-cidr 默认: 10.96.0.0/12
### 根据命令行配置初始化集群
kubeadm init --kubernetes-version=v$k8ver --pod-network-cidr=10.112.0.0/14 --image-repository=gcr.azk8s.cn/google-containers --dry-run
### 根据配置文件初始化集群
kubeadm init --config kubeadmin-init.yaml --dry-run

# Images Mirrors
# ali: registry.cn-hangzhou.aliyuncs.com/google_containers
# azure: gcr.azk8s.cn/google-containers

# 如果发现kube-proxy 没有使用LVS，可以采用如下方式修改为LVS

```bash
# 修改 kube-proxy 配置文件, 将 config.conf 中mode值改为 ipvs
kubectl edit cm kube-proxy -n kube-system

# 删除proxy pod，自动拉取新的
kubectl get pod -n kube-system -o name -l k8s-app=kube-proxy | xargs -n1 kubectl delete -n kube-system

```

# 部署 pod 网络 addon 采用 calico
```bash
# 默认 CALICO_IPV4POOL_CIDR 为 192.168.0.0/16 需要k8s集群的 cluster-cidr为此ippool
kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
```
