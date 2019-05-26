docker pull nginx:1.16-alpine

docker tag nginx:1.16-alpine nginx

* 容器内配置文件：
  * http /etc/nginx/nginx.conf
  * server  /etc/nginx/conf.d/default.conf
* 工作根目录： /usr/share/nginx/html

server 配置文件样例
```
server {
    listen 80;
    server_name localhost;
    charset utf8;
    location / {
       root /usr/share/nginx/html；
       index index.html index.htm;
    }
}
```

# 负载均衡实验
配置文件`slb.conf`
```
upstream backends {
  random;
  server 192.168.1.27:32769;
  server 192.168.1.27:32768;
}
server {
  listen 80;
  server_name  localhost;
  location / {
    proxy_pass  http://backends;
    add_header  X-Upstream  $upstream_addr;
    add_header  X-Upstream-Status  $upstream_status;
  }
}
```
运行测试
```
#!/bin/bash

docker rm -f ng1 ng2 ngx

echo "nginx1 32768" > ng1.html
echo "nginx2 32769" > ng2.html

docker run -id -p32768:80 -v `pwd`/ng1.html:/usr/share/nginx/html/index.html --name ng1 nginx
docker run -id -p32769:80 -v `pwd`/ng2.html:/usr/share/nginx/html/index.html --name ng2 nginx

docker run -id -p32770:80 -v `pwd`/slb.conf:/etc/nginx/conf.d/default.conf --name ngx nginx

for _ in {1..6}
do
	curl -vv -qs http://$HOSTNAME:32770
done
```
