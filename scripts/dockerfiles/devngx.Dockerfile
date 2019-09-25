FROM centos

LABEL maintainer="xiaowei <xiaow10@chinaunicom.cn>"
LABEL version="0.2"
LABEL description="a long running docker images to developer debug"

RUN set -ex \
    && yum -y install epel-release tar wget vim\
    && wget -O /etc/yum.repos.d/epel-apache-maven.repo  http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo \
    && yum makecache fast \
    && yum -y groupinstall "Development Tools" \
    && yum install -y zlib-devel libcurl-devel openssl-devel cyrus-sasl-devel cyrus-sasl-md5 \
    && yum install -y apr-devel apr-util-devel \
    && yum -y install nginx java-11-openjdk \
    && yum -y install apache-maven git subversion-devel \
    && yum -y install nmap-ncat psmisc net-tools bind-utils curl python-setuptools python2-pip unzip python36-devel python36-pip\
    && yum -y install python2-requests python2-pyyaml python-jwt \
    && yum -y install python36-requests python36-PyYAM python36-jwt \
    && mkdir -p ~/.config/pip \
    && echo -e "[global]\nindex-url = http://mirrors.aliyun.com/pypi/simple/\n[install]\ntrusted-host=mirrors.aliyun.com" > ~/.config/pip/pip.conf \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
    && ( test -d /root/.m2 || mkdir /root/.m2 ) \
    && pip install --no-cache-dir --upgrade --ignore-installed bottle pyjwt \
    && pip3 install --no-cache-dir --upgrade --ignore-installed bottle pyjwt

EXPOSE 80

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]