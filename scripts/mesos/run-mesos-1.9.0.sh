#!/bin/bash

#author: xiaowei


#using rpm to install mesos

ver=1.9.0

## prepare requires
mesosrpm=/data/mesos-$ver.rpm
sdir=/usr/local/mesos-$ver

[ -d /var/run/mesos ] || mkdir /var/run/mesos
rm -rf /var/run/mesos/*

[ -d /var/log/mesos ] || mkdir /var/log/mesos
rm -rf /var/log/mesos/*

[ -d $sdir ] || mkdir $sdir

dirpath=`dirname $mesosrpm`
[ -d $dirpath ] || mkdir -p $dirpath

echo "Check Mesos RPM File"
if [[ x$ver == "x1.9.0" ]] && [[ ! -f $mesosrpm ]]; then
	echo "Download mesos $ver rpm"
	wget -O $mesosrpm https://tools.xwsea.com/static/mesos-1.9.0-1.el7.x86_64.rpm
fi

echo "Check svn repository"
if [ ! -f /etc/yum.repos.d/wandisco-svn.repo ]; then
cat > /etc/yum.repos.d/wandisco-svn.repo <<EOF
[WANdiscoSVN]
name=WANdisco SVN Repo 1.9
enabled=1
baseurl=http://opensource.wandisco.com/centos/7/svn-1.9/RPMS/\$basearch/
gpgcheck=1
gpgkey=http://opensource.wandisco.com/RPM-GPG-KEY-WANdisco
EOF
fi

osname=$(grep PRETTY_NAME /etc/os-release)
if [[ $osname == 'PRETTY_NAME="CentOS Linux 8 (Core)"' ]] ; then
	rpm -qa | grep subversion || yum -y install subversion cyrus-sasl-md5
else
	echo $osname
	rpm -qa | grep subversion || yum -y install subversion-libs cyrus-sasl-md5 ntp
fi

img=zookeeper:3.4.12
docker images --format '{{.Repository}}:{{.Tag}}' | grep "$img" || docker pull $img

if [[ ! -f $mesosrpm ]]; then

rpmrepo=https://apache.bintray.com/mesos/el7/x86_64/
wget -O $mesosrpm $rpmrepo/mesos-$ver-1.el7.x86_64.rpm

fi

if [ ! -f $mesosrpm ] ; then
	echo "mesos rpm not exists"
	exit
fi

# /lets just rpm install it,
# notice mesos rpm not support relocate
rpm -qa | grep mesos-$ver || rpm -ivh $mesosrpm

docker ps -a --format '{{.Names}}' | grep ^mesos | xargs -n1 docker rm -f 2>/dev/null

echo "Now Start zookeeper"
docker ps -a --format '{{.Names}}' | grep '^zk$' && docker rm -f zk
docker run -d --net host --name zk zookeeper:3.4.12


hostdomain=$(hostname -d)

if [[ x$hostdomain == "xshared" ]]; then
	internalIP=$(ip addr s | grep inet | grep -Po "10\.[\d.]*/" | grep -Po "[.\d]*")
	outIP=$internalIP
else
        internalIP=$(ip addr s eth0 | grep -Po "10\.[.\d]*/" | grep -Po "[.\d]*")
        outIP=$(curl -qs ifconfig.me)
fi

echo "Get current host ip address: $internalIP, public: $outIP"

cat << EOF > /etc/mesos/mesos-master-env.sh
export MESOS_zk=zk://$internalIP:2181/mesos
export MESOS_quorum=1
export MESOS_cluster=xiaowei-mesos
export MESOS_log_dir=/var/log/mesos
export MESOS_work_dir=/var/run/mesos

#export MESOS_IP=$internalIP
#export LIBPROCESS_ADVERTISE_IP=$outIP
export MESOS_ADVERTISE_IP=$outIP
export MESOS_agent_removal_rate_limit=1/3mins
EOF

cat << EOF > /etc/mesos/mesos-agent-env.sh
export MESOS_MASTER=zk://$internalIP:2181/mesos
#export MESOS_IP=$internalIP
export MESOS_ADVERTISE_IP=$outIP
export MESOS_work_dir=/var/run/mesos
export MESOS_log_dir=/var/log/mesos
#export MESOS_isolation=cgroups
export MESOS_isolation=cgroups/cpu,cgroups/mem
export MESOS_CONTAINERIZERS=docker,mesos

#export MESOS_modules_dir=
#export MESOS_hooks=
EOF


echo "Now Start mesos"

# run mesos master
mesos-daemon.sh mesos-master

sleep 2

# run mesos agent
mesos-daemon.sh mesos-agent

img=mesosphere/marathon:v1.6.549
docker images --format '{{.Repository}}:{{.Tag}}' | grep "$img" || docker pull $img

# run marathon
echo "Now Start marathon"
docker ps -a --format '{{.Names}}' | grep '^marathon$' && docker rm -f marathon
docker run -d --net host --name marathon mesosphere/marathon:v1.6.549 --master zk://$internalIP:2181/mesos --zk zk://$internalIP:2181/marathon


cat << EOF > $HOME/app-nginx.json
{"cmd":null,"cpus":0.5,"mem":64,"disk":10,"instances":1,"id":"/nginx-app","container":{"docker":{"image":"nginx:1.16-alpine"},"type":"DOCKER","portMappings":[{"containerPort":80,"protocol":"tcp","name":null,"labels":null}],"volumes":[]},"networks":[{"mode":"container/bridge"}],"env":{},"labels":{},"healthChecks":[{"protocol":"HTTP","path":"/","portIndex":0,"gracePeriodSeconds":300,"intervalSeconds":60,"timeoutSeconds":20,"maxConsecutiveFailures":3}]}
EOF

cat << EOF > $HOME/app-nginx2.json
{"cmd":null,"cpus":0.5,"mem":64,"disk":10,"instances":1,"id":"/nginx-app-privileged","container":{"docker":{"image":"nginx:1.16-alpine", "privileged":true},"type":"DOCKER","portMappings":[{"containerPort":80,"protocol":"tcp","name":null,"labels":null}],"volumes":[]},"networks":[{"mode":"container/bridge"}],"env":{},"labels":{},"healthChecks":[{"protocol":"HTTP","path":"/","portIndex":0,"gracePeriodSeconds":300,"intervalSeconds":60,"timeoutSeconds":20,"maxConsecutiveFailures":3}]}
EOF

# run apps

img=nginx:1.16-alpine
docker images --format '{{.Repository}}:{{.Tag}}' | grep "$img" || docker pull $img

echo "curl --connect-timeout 9 -X POST -H 'Content-Type: application/json' -d@$HOME/app-nginx.json http://$internalIP:8080/v2/apps"

echo -e "\n\n now start nginx app"
curl --connect-timeout 9 -X POST -H 'Content-Type: application/json' -d@app-nginx.json http://$internalIP:8080/v2/apps

