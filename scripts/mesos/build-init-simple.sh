#!/bin/bash

#author: xiaowei
#date: 2018-01-30

# apache version
yum install -y tar wget git

yum install -y epel-release

yum groupinstall -y "Development Tools"

yum install -y python-devel python-six python-virtualenv java-1.8.0-openjdk-devel \
zlib-devel libcurl-devel openssl-devel cyrus-sasl-devel cyrus-sasl-md5 apr-devel apr-util-devel


### start building

# ./bootstrap && mkdir build && cd build
# ../configure --prefix=/usr/local/mesos-1.1.1
