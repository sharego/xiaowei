
#!/bin/bash

#author: xiaowei

# Only Support amd64 arch

# get this: curl -O https://raw.githubusercontent.com/sharego/xiaowei/master/scripts/linux/init-os-env.sh

# configuration

install_zsh=1
install_privateregistrycert=0
install_docker=1

# start work

if [[ `whoami` == 'root' ]]; then
    sudorun=''
else
    sudorun='sudo'
fi

$sudorun yum install -y yum-utils
$sudorun yum -y install epel-release
$sudorun yum -y install wget bash-completion bash-completion-extras nmap-ncat psmisc net-tools bind-utils curl python-setuptools python2-pip unzip python36-devel python36-pip

which jq
if [[ $? -ne 0 ]]; then
$sudorun wget -O /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod a+x /usr/local/bin/jq
fi
$sudorun yum makecache fast


# 官方源
$sudorun yum-config-manager --add-repo http://download.docker.com/linux/centos/docker-ce.repo

# 阿里源
# wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 清华大学源
# wget -O /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo
# sed -i 's+download.docker.com+mirrors.tuna.tsinghua.edu.cn/docker-ce+' /etc/yum.repos.d/docker-ce.repo


$sudorun mkdir /etc/docker
mkdir -p ~/.config/pip ~/.docker

$sudorun systemctl stop firewalld
$sudorun systemctl disable firewalld
$sudorun setenforce 0

$sudorun sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

$sudorun cat >> /etc/sysctl.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

tee ~/.config/pip/pip.conf << EOF
[global]
index-url = http://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host=mirrors.aliyun.com
EOF

$sudorun cat > /etc/docker/daemon.json << EOF
{
    "storage-driver": "overlay2",
    "data-root":"/var/lib/docker",
    "insecure-registries":["10.172.49.246", "harbor.dcos.xixian.unicom.local"],
    "registry-mirrors":["https://registry.docker-cn.com", "https://0ea2p7tt.mirror.aliyuncs.com"],
    "log-driver":"json-file",
    "hosts":["tcp://127.0.0.1:2375", "unix:///var/run/docker.sock"],
    "containerd": "/run/containerd/containerd.sock"
}
EOF

cat > ~/.docker/config.json << EOF
{
        "experimental": "enabled"
}
EOF

# just for work

if [[ install_privateregistrycert == 1 ]]; then
    $sudorun mkdir -p /etc/docker/certs.d
    export HABHN=reg.mg.hcbss HABIP=10.124.142.43 CRTIP=10.124.142.43 && echo -e "\n$HABIP  $HABHN" >> /etc/hosts

    $sudorun mkdir /etc/docker/certs.d/$HABHN && $sudorun wget -O /etc/docker/certs.d/$HABHN/$HABHN.crt http://$CRTIP/keys/$HABHN.crt

if

if [[ install_docker -eq 1 ]]; then
    $sudorun yum -y install docker-ce
if

dockerservice=/usr/lib/systemd/system/docker.service
if [[ -f $dockerservice ]]; then
    $sudorun sed -i 's#ExecStart=/usr/bin/dockerd.*#ExecStart=/usr/bin/dockerd#g' $dockerservice
    $sudorun systemctl daemon-reload
    $sudorun systemctl enable docker
    $sudorun systemctl start docker
fi

# add docker-compose
$sudorun curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
$sudorun chmod a+x /usr/local/bin/docker-compose

# 个人电脑多保存一些 history
$sudorun sed -i 's/HISTSIZE=1000/HISTSIZE=50000/g' /etc/profile


# 个人电脑ssh 存活120分钟, 即2个小时
$sudorun sed -i 's/.*ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config
$sudorun sed -i 's/.*ClientAliveCountMax.*/ClientAliveCountMax 120/' /etc/ssh/sshd_config

# 看使用习惯, 可以不安装, 安装后执行uninstall_oh_my_zsh 卸载
# use zsh & oh-my-zsh (oh-my-zsh need git)

if [[ $install_zsh -eq 1 ]]; then

# 看使用习惯, 可以不安装, 也安装后执行uninstall_oh_my_zsh 卸载
$sudorun yum -y install zsh


sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# configure zsh, add plugins
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

sed -i '/^plugins/s/)$/ zsh-syntax-highlighting)/' ~/.zshrc

# configure zsh, add alias
echo "alias ls='ls --color=auto'" >> ~/.zshrc
echo "alias ll='ll --color=auto'" >> ~/.zshrc
echo "alias gcn='git commit -a --dry-run'" >> ~/.zshrc

fi


echo "All Done, Now advise to restart the machine"
