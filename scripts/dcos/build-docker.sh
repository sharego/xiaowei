#!/bin/bash

# prepare dcos container

cat << EOF > $workdir/.bash_profile

# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/bin

export PATH
EOF

cat << EOF > $workdir/.bashrc
# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi
EOF

# run docker container

wget -O $workdir/build-init.sh https://raw.githubusercontent.com/sharego/xiaowei/master/scripts/dcos/build-docker-inner.sh

## start zk
# sudo docker run -id 

## start devdcos


sudo docker run -id -v $workdir:/root  --name devdcos centos:7.6


