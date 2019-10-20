#!/bin/bash

#author: xiaowei


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
yum install -y --disableexcludes=kubernetes kubeadm-1.15.3

    ## yum install -y --disableexcludes=kubernetes kubeadm-1.15.3 kubelet-1.15.3 kubectl-1.15.3

## configuration file

### according https://kubernetes.io/docs/setup/best-practices/cluster-large/
### most of 150000 total pods on 5000 nodes

cat <<EOF > kubeadm-init.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.15.3 # kubernetes的版本
networking:
  podSubnet: 10.112.0.0/14 # pod网络的网段
kubeProxy:
  config:
    mode: ipvs   #启用IPVS模式
featureGates:
  CoreDNS: true
imageRepository: gcr.azk8s.cn/google-containers # image的仓库源
EOF

# 只拉取镜像
# kubeadm config images pull --config kubeadm-init.yaml
# 列举镜像列表
# kubeadm config images list

## use command line configuration
### service-cidr 默认: 10.96.0.0/12
kubeadm init --kubernetes-version=v1.15.3 --pod-network-cidr=10.112.0.0/14 --image-repository=gcr.azk8s.cn/google-containers --dry-run

# Images Mirrors
# ali: registry.cn-hangzhou.aliyuncs.com/google_containers
# azure: gcr.azk8s.cn/google-containers
