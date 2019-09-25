FROM centos

LABEL maintainer="xiaowei <xiaow10@chinaunicom.cn>"

RUN set -ex \
    && yum -y install python-setuptools \
    &&
    && pip install PyYAML requests \
    && yum clean all \
    && cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ENV TZ "Asia/Shanghai"
ENV LANG "en_US.UTF8"