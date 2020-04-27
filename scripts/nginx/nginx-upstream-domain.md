**nginx 负载均衡场景下,单域名多A记录后端TCP健康检查**


# 1. Background

> 参考Nginx官方文档, upstream指令[^1]

`upstream`的`server`配置项中可以指定失败参数`max_fails`, 如下：
```
upstream dynamic {
    zone upstream_dynamic 64k;

    server backend1.example.com      weight=5;
    server backend2.example.com:8080 fail_timeout=5s slow_start=30s;
    server 192.0.2.1                 max_fails=3;
    server backend3.example.com      resolve;
    server backend4.example.com      service=http resolve;

    server backup1.example.com:8080  backup;
    server backup2.example.com:8080  backup;
}
```
其中`max_fails`的详细解释为:
> sets the number of unsuccessful attempts to communicate with the server that should happen in the duration set by the fail_timeout parameter to consider the server unavailable for a duration also set by the fail_timeout parameter. By default, the number of unsuccessful attempts is set to 1. The zero value disables the accounting of attempts. What is considered an unsuccessful attempt is defined by the proxy_next_upstream, fastcgi_next_upstream, uwsgi_next_upstream, scgi_next_upstream, memcached_next_upstream, and grpc_next_upstream directives.

简单的说，通过配合`fail_timeout`和`max_fails`，可以把一个server标记为`unavailable`, 但如果server配置只有一个，其实是多实例后端呢？

# 2. 测试


## 2.1. 测试配置

### 2.1.1. nginx lb 配置
```
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log info;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;

    resolver 172.18.1.2 valid=10s;

    upstream backends {
        server app.xw.local max_fails=2 fail_timeout=2s;
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
}

```

### 2.1.2. nginx app 配置1
```
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log info;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;

    resolver 172.18.1.2 valid=10s;

    server {
        listen 80;
        server_name  app.xw.local app1.xw.local;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
    }
}

```

### 2.1.3. nginx app 配置2
```
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log info;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    sendfile        on;

    resolver 172.18.1.2 valid=10s;

    server {
        listen 80;
        server_name  app.xw.local app2.xw.local;
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }
    }
}

```

### 2.1.4. dns 配置
此处使用coredns

```
#Corefile
xw.local:53 {
    hosts xw.local.hosts
    log
    errors
    debug
}

# hosts file

172.18.1.11 app.xw.local
172.18.1.11 app1.xw.local
172.18.1.12 app.xw.local
172.18.1.12 app2.xw.local
172.18.1.3  lb.xw.local

```

## 2.2. 运行测试环境

采用`docker-compose`运行容器

```yaml
version: "2.4"
services:
  dns:
    image: coredns/coredns:latest
    container_name: dns
    volumes:
      - ./Corefile:/Corefile
      - ./xw.local.hosts:/xw.local.hosts
    networks:
      appnet:
        ipv4_address: 172.18.1.2

  app1:
    image: ng:latest
    container_name: app1
    dns: 172.18.1.2
    volumes:
      - ./app1.conf:/etc/nginx/nginx.conf
      - ./app1.html:/usr/share/nginx/html/index.html
    networks:
      appnet:
        ipv4_address: 172.18.1.11

  app2:
    image: ng:latest
    container_name: app2
    dns: 172.18.1.2
    volumes:
      - ./app2.conf:/etc/nginx/nginx.conf
      - ./app2.html:/usr/share/nginx/html/index.html
    networks:
      appnet:
        ipv4_address: 172.18.1.12

  lb:
    image: ng:latest
    container_name: lb
    dns:
      - 172.18.1.2
    volumes:
      - ./slb1.conf:/etc/nginx/nginx.conf
    networks:
      appnet:
        ipv4_address: 172.18.1.3

networks:
  appnet:
    driver: bridge
    enable_ipv6: false
    ipam:
      driver: default
      config:
        - subnet: 172.18.1.0/24
          gateway: 172.18.1.1

```

运行 `docker-compose up -d` 即可启动以上4个容器

## 2.3. 启动测试

进入lb容器，执行`time curl -vv lb.xw.local`，可以查看lb的负载情况, 在所有容器正常时，lb正常负载。然后停止`docker stop app2`, 继续测试得到以下结果:
```
[root@0f9f22381e61 /]# time curl -vv lb.xw.local
* Rebuilt URL to: lb.xw.local/
*   Trying 172.18.1.3...
* TCP_NODELAY set
* Connected to lb.xw.local (172.18.1.3) port 80 (#0)
> GET / HTTP/1.1
> Host: lb.xw.local
> User-Agent: curl/7.61.1
> Accept: */*
>
< HTTP/1.1 200 OK
< Server: nginx/1.14.1
< Date: Mon, 27 Apr 2020 15:34:42 GMT
< Content-Type: text/html
< Content-Length: 5
< Connection: keep-alive
< Last-Modified: Mon, 27 Apr 2020 15:31:44 GMT
< ETag: "5ea6fae0-5"
< Accept-Ranges: bytes
< X-Upstream: 172.18.1.12:80, 172.18.1.11:80
< X-Upstream-Status: 502, 200
<
app1
* Connection #0 to host lb.xw.local left intact

real	0m3.027s
user	0m0.007s
sys	0m0.011s
```

# 3. 结论

在nginx 1.14 版本中，当upstream采用域名作为后端服务地址，dns解析ip有多个时，会自动的请求下一个ip，并正常返回内容，但返回时间包含超时检测时间。


# 4. Ref
[^1]: [https://nginx.org/en/docs/http/ngx_http_upstream_module.html](https://nginx.org/en/docs/http/ngx_http_upstream_module.html)
