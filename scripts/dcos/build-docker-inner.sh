#!/bin/bash

#author: xiaowei
#date: 2018-01-30


# ---> prepare build mesos
grep LIBPROCESS_IP ~/.bashrc
if [[ $? -ne 0 ]]; then
echo 'first init'
# if we want to compile marathon, we can use mvm.sh to compile multiple mesos version this use the $HOME directory
export mesosversion='1.7.2'

# apache version
yum install -y tar wget git vim

wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
yum install -y epel-release

cat > /etc/yum.repos.d/wandisco-svn.repo <<EOF
[WANdiscoSVN]
name=WANdisco SVN Repo 1.9
enabled=1
baseurl=http://opensource.wandisco.com/centos/7/svn-1.9/RPMS/\$basearch/
gpgcheck=1
gpgkey=http://opensource.wandisco.com/RPM-GPG-KEY-WANdisco
EOF

yum groupinstall -y "Development Tools"

yum install -y python36-devel python36-pip python36-virtualenv python36-six apache-maven python-devel python-pip python-six python-virtualenv java-1.8.0-openjdk-devel zlib-devel libcurl-devel openssl-devel cyrus-sasl-devel cyrus-sasl-md5 apr-devel subversion-devel apr-util-devel


### start building

# git clone https://github.com/apache/mesos.git
# cd mesos && git checkout $mesosversion
# ./bootstrap && mkdir build && cd build
# ../configure --prefix=/opt/mesos-mesosversion

# ---> prepare build marathon

yum install -y libevent-devel openssl-devel net-tools

curl https://bintray.com/sbt/rpm/rpm | tee /etc/yum.repos.d/bintray-sbt-rpm.repo

yum install -y sbt

# sed -i 's/sbt_default_mem=1024/sbt_default_mem=4096/' /usr/bin/sbt

test -d $HOME/.sbt || mkdir $HOME/.sbt
cat << EOF > $HOME/.sbt/repositories
[repositories]
local
aliyunmaven: http://maven.aliyun.com/nexus/content/groups/public
EOF

mkdir -p $HOME/.config/pip
cat << EOF > $HOME/.config/pip/pip.conf
[global]
index-url = http://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host=mirrors.aliyun.com
EOF

# /usr/sbin/ip, /usr/bin/grep

cat  << EOF >> /root/.bashrc
HOSTIP=$(ip addr s eth0 | grep -Po 'inet 172[.\d]*' | grep -o '172.*')
export HOSTIP
export LIBPROCESS_IP="$HOSTIP"
EOF

# donot do it replace with mvm.sh
# git clone https://github.com/apache/mesos.git

git clone https://github.com/mesosphere/marathon.git
cd marathon/tools
bash mvm.sh --list # download mesos repo
ln -s $HOME/.mesos/mesos_src $HOME/mesos

# compile mesos version

cd $HOME/marathon/tools
# export MESOS_MAKE_JOBS=16
bash mvm.sh $mesosversion bash

# compile marathon

cd $HOME/marathon
sbt 'run --master localhost:5050 --zk zk://zookeeper:2181/marathon'

else
  echo 'not first, now update git repos'
  cd ~/mesos && git fetch
  cd ~/marathon && git fetch
fi


