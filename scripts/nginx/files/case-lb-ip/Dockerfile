FROM docker-hub.didiyun.com/library/centos:latest

RUN set -ex \
    && yum -y install nginx  bind-utils

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

EXPOSE 80
