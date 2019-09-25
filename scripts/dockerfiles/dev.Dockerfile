FROM centos

LABEL maintainer="xiaowei <xiaow10@chinaunicom.cn>"

RUN set -ex \
    && yum -y install python-setuptools \
    && easy_install https://files.pythonhosted.org/packages/00/9e/4c83a0950d8bdec0b4ca72afd2f9cea92d08eb7c1a768363f2ea458d08b4/pip-19.2.3.tar.gz \
    && mkdir -p ~/.config/pip \
    && echo -e "[global]\nindex-url = http://mirrors.aliyun.com/pypi/simple/\n[install]\ntrusted-host=mirrors.aliyun.com" > ~/.config/pip/pip.conf \
    && pip --no-cache-dir install PyYAML requests \
    && yum clean all \
    && cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

ENV TZ "Asia/Shanghai"
ENV LANG "en_US.UTF8"
