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

    resolver 10.255.0.179:10053 valid=10s;

    upstream backends {
        server app.xw.local max_fails=3 fail_timeout=2s;
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

    resolver 10.255.0.179:10053 valid=10s;

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

    resolver 10.255.0.179:10053 valid=10s;

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
xw.local:10053 {
    hosts /etc/coredns/xw.local.hosts
    log
    errors
    debug
}

# hosts file

172.17.0.2 app.xw.local
172.17.0.3 app.xw.local

```

## 2.2. 运行测试环境

### 2.2.1. 运行nginx

### 2.2.2. 运行coredns

## 2.3. 启动测试


# 3. 结论

# 4. Ref
[^1]: [https://nginx.org/en/docs/http/ngx_http_upstream_module.html](https://nginx.org/en/docs/http/ngx_http_upstream_module.html)