yum install -y yum-utils
yum -y install epel-release
yum -y install wget  nmap-ncat psmisc net-tools bind-utils curl python-setuptools python2-pip unzip
wget -O /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod a+x /usr/local/bin/jq
yum makecache fast

# 官方源
yum-config-manager --add-repo http://download.docker.com/linux/centos/docker-ce.repo

# 阿里源
# wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 清华大学源
# wget -O /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo
# sed -i 's+download.docker.com+mirrors.tuna.tsinghua.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo

mkdir ~/.pip /etc/docker
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed  -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

cat >> /etc/sysct.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

tee ~/.pip/pip.conf << EOF
[global]
index-url = http://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host=mirrors.aliyun.com
EOF

cat > /etc/docker/daemon.json << EOF
{
    "storage-driver": "overlay2",
    "data-root":"/var/lib/docker",
    "insecure-registries":["10.172.49.246"],
    "registry-mirrors":["https://registry.docker-cn.com", "https://0ea2p7tt.mirror.aliyuncs.com"],
    "log-driver":"json-file",
    "hosts":["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"],
    "containerd": "/run/containerd/containerd.sock"
}
EOF

sed -i 's#ExecStart=/usr/bin/dockerd.*#ExecStart=/usr/bin/dockerd#g'  /usr/lib/systemd/system/docker.service
systemctl daemon-reload

# add docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod a+x /usr/local/bin/docker-compose

# 个人电脑多保存一些 history
sed -i 's/HISTSIZE=1000/HISTSIZE=50000/g' /etc/profile

# 看使用习惯, 可以不安装, 安装后执行uninstall_oh_my_zsh 卸载
# use zsh & oh-my-zsh
yum -y install zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
