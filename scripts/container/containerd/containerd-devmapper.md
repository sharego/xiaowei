# use `devmapper`

```bash
# 安装 dmsetup /usr/sbin/dmsetup
yum -y install device-mapper
# 安装 golang
wget https://dl.google.com/go/go1.13.9.linux-amd64.tar.gz
tar axf go1.13.9.linux-amd64.tar.gz
mv go /usr/local/go
# 配置go环境变量, 也可以配置 ~/.bash_profile 文件
export GOROOT=/usr/local/go
export PATH=$HOME/bin:$GOROOT/bin:$PATH
# 准备 protoc
wget https://github.com/protocolbuffers/protobuf/releases/download/v3.11.4/protoc-3.11.4-linux-x86_64.zip
unzip protoc-3.11.4-linux-x86_64.zip
mv include/google /usr/local/include/
# 安装 git
yum -y install git
# 下载 containerd 源码, 按go工程目录放置
mkdir -p src/github.com/containerd
cd src/github.com/containerd
git clone https://github.com/containerd/containerd.git
cd containerd
# 安装 libseccomp
yum -y install libseccomp-devel
# 编译 containerd
make BUILDTAGS=no_btrfs
# 将编译结果拷贝到用户目录下
cp -r bin ~/
# 设置containerd的systemd文件
cp containerd.service /etc/systemd/system
mkdir /etc/containerd
# 准备containerd默认配置文件
containerd config default > /etc/containerd/config.toml

# 准备devmapper设备
## 此处使用loop文件，必须加载在ext4文件系统之上
## 使用vg创建一个lv，格式化为ext4
lvcreate -L 15G -n datavg lvdevm
mkfs.ext4 /dev/datavg/lvdevm
mkdir /var/lib/containerd/devmapper
mount /dev/datavg/lvdevm /var/lib/containerd/devmapper
## 将下面的内容保存到一个文件，执行创建dm设备


#!/bin/bash

set -ex

DATA_DIR=/var/lib/containerd/devmapper
POOL_NAME=containerd-pool

test -e ${DATA_DIR} || mkdir -p ${DATA_DIR}

# Create data file
sudo touch "${DATA_DIR}/data"
sudo truncate -s 100G "${DATA_DIR}/data"

# Create metadata file
sudo touch "${DATA_DIR}/meta"
sudo truncate -s 10G "${DATA_DIR}/meta"

# Allocate loop devices
DATA_DEV=$(sudo losetup --find --show "${DATA_DIR}/data")
META_DEV=$(sudo losetup --find --show "${DATA_DIR}/meta")

# Define thin-pool parameters.
# See https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt for details.
SECTOR_SIZE=512
DATA_SIZE="$(sudo blockdev --getsize64 -q ${DATA_DEV})"
LENGTH_IN_SECTORS=$(bc <<< "${DATA_SIZE}/${SECTOR_SIZE}")
DATA_BLOCK_SIZE=128
LOW_WATER_MARK=32768

# Create a thin-pool device
sudo dmsetup create "${POOL_NAME}" \
    --table "0 ${LENGTH_IN_SECTORS} thin-pool ${META_DEV} ${DATA_DEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK}"

cat << EOF
#
# Add this to your config.toml configuration file and restart containerd daemon
#
[plugins]
  [plugins.devmapper]
    pool_name = "${POOL_NAME}"
    root_path = "${DATA_DIR}"
    base_image_size = "10GB"
EOF

# 以上文件执行后, 调用 dmsetup ls 可以看到创建的 containerd-pool


# 修改containerd的配置文件 /etc/containerd/config.toml
# 加入plugins.devmapper配置，并修改snapshotter = "overlayfs" 为 snapshotter = "devmapper"

# 修改 service文件可执行文件路径
sed -i 's#/usr/local/bin/containerd#$HOME/bin/containerd#g' /etc/systemd/system/containerd.service
systemctl daemon-reload

# 启动containerd服务
systemctl start containerd
ctr plugin ls | grep devmapper

```

# container test

```
# 先准备 runc
wget https://github.com/opencontainers/runc/releases/download/v1.0.0-rc10/runc.amd64
chmod a+rx runc.amd64
mv runc.amd64 /usr/local/bin/runc

# 测试容器
ctr images pull --snapshotter devmapper docker.io/library/hello-world:latest

ctr run --snapshotter devmapper docker.io/library/hello-world:latest c1

ctr images pull --snapshotter overlayfs docker.io/library/hello-world:latest

ctr run --snapshotter overlayfs docker.io/library/hello-world:latest c2

```
