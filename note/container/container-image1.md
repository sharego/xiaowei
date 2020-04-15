# 你不可不知的容器镜像（系列一）

> 重拾容器镜像标准

因为ARM架构的兴起，对于ARM架构与X86架构下的容器镜像的差异，有很多同学表示有兴趣。容器镜像之于云原生就像水、电之于城市一样，是云原生下最重要的基础设施和技术标准。我们使用最多，但其技术通常都忽视了。事实上，这也是**Docker, Inc**对开源技术社区最大的贡献。现在大家可以像使用`Git`一样，创建修改容器镜像，管理容器镜像仓库，都来源于DotCloud即Docker公司的贡献。

## 一、容器镜像基本命令

1. `docker pull`  从容器仓库中获取容器镜像
2. `docker push` 将本地镜像推送到容器仓库中
3. `docker tag` 容器镜像创建tag
4. `docker save`  将本地容器镜像保存为tar文件
5. `docker load` 从文件加载容器镜像
6. `docker build` 根据`Dockerfile`构建新镜像
7. `docker rmi` 删除容器镜像
8. `docker image` 容器镜像管理


## 二、容器镜像的格式

从上述命令的交互使用，可以看到容器镜像是分层组织的。如下载一个镜像时：
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z nginx]# docker pull nginx:1.16-alpine
1.16-alpine: Pulling from library/nginx
9d48c3bd43c5: Already exists
7a56a3a1208e: Pull complete
Digest: sha256:096c4b3464e2e465f20e9d704f1a0f8d27584df4d6758b6d00a14911cc9bb888
Status: Downloaded newer image for nginx:1.16-alpine
docker.io/library/nginx:1.16-alpine
```
有两个并发下载`9d48`和`7af6a`，这也就是大家常说的分层联合文件系统的两个分层。通过该技术，我们可以快捷的修改容器镜像，像`git`一样来提交`commit`修改创建新的镜像，同时复用旧有镜像，并发下载等等。

通过`docker inspect`命令可以查看容器镜像的分层信息，如上述`nginx:1.16-alpine`镜像
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z nginx]# docker inspect nginx:1.16-alpine | jq '.[0].RootFS'
{
  "Type": "layers",
  "Layers": [
    "sha256:03901b4a2ea88eeaad62dbe59b072b28b6efa00491962b8741081c5df50c65e0",
    "sha256:acdd6738af44e55d8f81bbd7bfa1ecf5f8838c91468fb8f66200783eccb1fe81"
  ]
}
```
可以看到该`nginx:1.16-alpine`容器镜像由采用`layers`类型即分层文件系统存储, 并且有两层, 每层的id也进行了记录。
通过检查`alpine:3.10`的分层信息，可以看到同样的层id
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z nginx]# docker inspect alpine:3.10 | jq '.[0].RootFS'
{
  "Type": "layers",
  "Layers": [
    "sha256:03901b4a2ea88eeaad62dbe59b072b28b6efa00491962b8741081c5df50c65e0"
  ]
}
```
我们也可以将该容器镜像保存为文件，通过计算得到相同的摘要，如下：
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z nginximage]# sha256sum 7d6cd6cc75dcb73a9203e00b7632c1f8225ee5ba5e9ae67397f09b5700ecda0f/layer.tar
03901b4a2ea88eeaad62dbe59b072b28b6efa00491962b8741081c5df50c65e0  7d6cd6cc75dcb73a9203e00b7632c1f8225ee5ba5e9ae67397f09b5700ecda0f/layer.tar
[root@iZm5e9qnmldt4il3o1hxf1Z nginximage]# sha256sum 373c10a6a844bc172be71a6755aedaa83cf7581641c9403e006db676febc76a1/layer.tar
907ca0bb94b6c58d56a786d0a7b8f298116735af4af152fbd18b8cb3b13eb2b4  373c10a6a844bc172be71a6755aedaa83cf7581641c9403e006db676febc76a1/layer.tar
```

容器镜像标准不只是一个分层，还有很多其他内容。根据OCI标准[^1]，容器镜像由4个部分组成，其中1个可选：
1. manifest 清单文件： 描述文件的元数据信息
2. index 索引文件：可选
3. configuration 配置文件
4. layers文件


## 三、容器镜像的标准
> 容器运行时和容器镜像在[Open Container Initiative (OCI)](https://www.opencontainers.org/)中进行了规范定义: OCI Runtime Specification 和 OCI Image Specification。但考虑到Docker使用更广泛，实际上也是更为事实的标准，以Docker的镜像标准进行研究。

### 3.1 Docker 镜像标准的版本

Docker镜像有两个版本 **V1** 和 **V2**， 最新版是V2，先以**V1**为例[^2]，对于一个归档文件（即`docker save`命令保存的结果），其结构如下：
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z nginximage]# tree -L 2
.
|-- 373c10a6a844bc172be71a6755aedaa83cf7581641c9403e006db676febc76a1
|   |-- json
|   |-- layer.tar
|   `-- VERSION
|-- 7d6cd6cc75dcb73a9203e00b7632c1f8225ee5ba5e9ae67397f09b5700ecda0f
|   |-- json
|   |-- layer.tar
|   `-- VERSION
|-- 8587e8f26fc1dd34343aea28526392d41bd3d73150ed67b3d214a2dd7304aa25.json
|-- manifest.json
`-- repositories
```
在此例子中，有4类部分：manifest.json、repositories、858*.json和两层分层目录。

1. `manifest.json`结构与`OCI`标准不一致，内容样例，如:
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z nginximage]# jq '.' manifest.json
[
  {
    "Config": "8587e8f26fc1dd34343aea28526392d41bd3d73150ed67b3d214a2dd7304aa25.json",
    "RepoTags": [
      "nginx:1.16-alpine"
    ],
    "Layers": [
      "7d6cd6cc75dcb73a9203e00b7632c1f8225ee5ba5e9ae67397f09b5700ecda0f/layer.tar",
      "373c10a6a844bc172be71a6755aedaa83cf7581641c9403e006db676febc76a1/layer.tar"
    ]
  }
]
```
其中manifest还可以一个可选项`parent`，值为parent镜像的Image Id

2.  manifest中有一个非常重要的配置项`Config`，该配置指定了镜像 Image JSON的文件路径，如样例中的`8587e8f26fc1dd34343aea28526392d41bd3d73150ed67b3d214a2dd7304aa25.json`。此文件描述了镜像的基本信息，如创建时间、容器运行配置（如Entrypoint、参数、映射端口、卷信息）、构建命令（构建历史）、分层信息。改文件内容的变更将导致镜像ID的变化，即该文件不可修改。

如此例中，其对象结构如下（值仅用数据类型表示）：
```
[
  "architecture": String,
  "config": Object	,
  "container": String,
  "container_config": Object,
  "created": String,
  "docker_version": String,
  "history": Array,
  "os": String,
  "rootfs": Array
]
```


3.  文件`repositories`也是一个**JSON**内容格式的文件，描述了该镜像的名称和标签，对同一个Image ID，我们可以多次执行`docker tag`赋予不同的标签
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z nginximage]# jq '.' repositories
{
  "nginx": {
    "1.16-alpine": "373c10a6a844bc172be71a6755aedaa83cf7581641c9403e006db676febc76a1"
  }
}
```

4. 分层文件目录，改目录路径不是固定，因为其路径在Image JSON中（即8587*.json）进行了描述， 即`rootfs`字段。对于每一层，一般有三个文件：
- VERSION： 内容一般是1.0
-  json： 每层的元数据信息描述文件，内容与容器镜像整体的Image JSON基本一致，但已不再采用，遗留用于保持向后兼容性
- layer.tar：每层的修改变化集的文件系统Tar归档文件（The Tar archive of the filesystem changeset for an image layer）

> 从以上信息可以得知：对于**x86**和**ARM**，必然会在Image JSON中`architecture`字段值不一样，也就会导致Image ID不一致。那如何使用同一镜像的Name和Tag来自动适配不同的芯片呢？这是可能的吗？ 按编剧安排，肯定是： Yes

### 3.2 Docker Image V1/V2

Docker显然考虑到了该问题，对Docker Image标准进行了更新，在V2版本中，添加了：多指令集架构的支持。简单的说，与V1相比有如下区别[^3]：

-   Image Spec V1
    -   Randomly generated image ID
    -   Image specific properties are defined at layer level
    -   No multi-architecture support
-   Image Spec V2
    -   Image IDs are content addresses
    -   Image specific properties defined at image level
    -   Multi-architecture support(Manifests, as Fat manifest or manifest list, optional)
    -   Image Signatures (Also in OCI)

### 3.3 Docker Image V2

新版Image  manifest list 样例（V2.2）[^4]：
```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
  "manifests": [
    {
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "size": 7143,
      "digest": "sha256:e692418e4cbaf90ca69d05a66403747baa33ee08806650b51fab815ad7fc331f",
      "platform": {
        "architecture": "arm64",
        "os": "linux",
      }
    },
    {
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "size": 7682,
      "digest": "sha256:5b0bcabd1ed22e9fb1310cf6c2dec7cdef19f0ad69efa1f392e94a4333501270",
      "platform": {
        "architecture": "amd64",
        "os": "linux",
        "features": [
          "sse4"
        ]
      }
    }
  ]
}
```
对于 Registry V2 而言，将根据Client的Content-Type判断返回manifests中某个platform的image，或者返回不存在改architecture的image错误信息。

### 3.4 实操 Manifest

- 准备工作

1. 首先我们需要一个docker（版本最好在18.09及以上）
2. 我们需要打开Docker Cli 的实验性功能，如下两种办法[^5]：
   - 设置环境变量：export DOCKER_CLI_EXPERIMENTAL=enabled
   - 修改客户端配置文件：docker 命令的客户端配置文件一般在~/.docker/config.json, 打开后添加一个配置项: `"experimental": "enabled"`

- 查看nginx项目镜像manifest: `docker manifest inspect nginx:1.16-alpine`
```json
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
   "manifests": [
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 739,
         "digest": "sha256:afdd87901ea8138232b01dd3dd2c592cc64ba2e250f8fbae7e63937e1a00bdc9",
         "platform": {
            "architecture": "amd64",
            "os": "linux"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 739,
         "digest": "sha256:2a8a231e854639205ae605b40f46521d0954e3f09fcfafb9fa6ef09815603649",
         "platform": {
            "architecture": "arm",
            "os": "linux",
            "variant": "v6"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 739,
         "digest": "sha256:572cd64e213a6c58dc50e1a57e9019747a0f7cf0303dfa2f7b7299a1c6715a14",
         "platform": {
            "architecture": "arm64",
            "os": "linux",
            "variant": "v8"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 739,
         "digest": "sha256:5f459249ad7e228add3def35b8d0a755ff97d4e4184d9912a12ebaeaa6af78db",
         "platform": {
            "architecture": "386",
            "os": "linux"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 739,
         "digest": "sha256:b8137c125c4f2af750dd4f45e732df3a00a1855e5228d32df6f4b0b7e99ee0a5",
         "platform": {
            "architecture": "ppc64le",
            "os": "linux"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 739,
         "digest": "sha256:6451f8b17908f47c364ea2bb3612a395ed21ea2f18e328431340f395bd531852",
         "platform": {
            "architecture": "s390x",
            "os": "linux"
         }
      }
   ]
}
```
可以看到nginx镜像支持6️⃣种CPU架构，那如果在不支持的镜像上`pull`会怎样呢？当然是报错啦
```
[root@ip-172-31-12-155 hello]# docker pull openjdk
Using default tag: latest
latest: Pulling from library/openjdk
no matching manifest for linux/arm64/v8 in the manifest list entries
```
那如果是没有manifest呢？如下：
```
[root@ip-172-31-12-155 hello]# docker pull xiaowei/hellonginx
Using default tag: latest
Error response from daemon: manifest for xiaowei/hellonginx:latest not found
```

- 制作manifest有什么好处？当然是跨架构容器镜像支持啊
- 怎么制作呢？[^6]
  1. 首先在arm主机和x86_64主机上分别制作两个镜像（`xiaowei/hello-x64`、`xiaowei/hello-arm64`）并push到hub.docker.com上
  2. `docker manifest create xiaowei/hello xiaowei/hello-x64 xiaowei/hello-arm64`
  3. `docker manifest annotate xiaowei/hello xiaowei/hello-x64 --os linux --arch amd64`
  4. `docker manifest annotate xiaowei/hello xiaowei/hello-arm64 --os linux --arch arm64 --variant v8`
  5. `docker manifest inspect xiaowei/hello`
```bash
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
   "manifests": [
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 527,
         "digest": "sha256:d9e70de2b7083a962261584cd62a9da53f63aa4ea173d200ef66de6857273486",
         "platform": {
            "architecture": "arm64",
            "os": "linux",
            "variant": "v8"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 527,
         "digest": "sha256:c05702440d309dc321d255da83bd9f433a116d1f3233d533f7249bc6aafd59b5",
         "platform": {
            "architecture": "amd64",
            "os": "linux"
         }
      }
   ]
}
```

  5. `docker manifest push xiaowei/hello`

```bash
[root@ip-172-31-12-155 hello]# docker manifest push xiaowei/hello
Pushed ref docker.io/xiaowei/hello@sha256:d9e70de2b7083a962261584cd62a9da53f63aa4ea173d200ef66de6857273486 with digest: sha256:d9e70de2b7083a962261584cd62a9da53f63aa4ea173d200ef66de6857273486
Pushed ref docker.io/xiaowei/hello@sha256:c05702440d309dc321d255da83bd9f433a116d1f3233d533f7249bc6aafd59b5 with digest: sha256:c05702440d309dc321d255da83bd9f433a116d1f3233d533f7249bc6aafd59b5
sha256:076ad95681ecd91893a9f7577673a333514a70048465cf08b8c5f82f8f223f35
```

  6. 拉取镜像, 验证结果
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z hello]# docker pull xiaowei/hello
Using default tag: latest
latest: Pulling from xiaowei/hello
Digest: sha256:076ad95681ecd91893a9f7577673a333514a70048465cf08b8c5f82f8f223f35
Status: Downloaded newer image for xiaowei/hello:latest
docker.io/xiaowei/hello:latest
[root@iZm5e9qnmldt4il3o1hxf1Z hello]# uname -i
x86_64
```
```bash
[root@ip-172-31-12-155 hello]# docker pull xiaowei/hello
Using default tag: latest
latest: Pulling from xiaowei/hello
Digest: sha256:076ad95681ecd91893a9f7577673a333514a70048465cf08b8c5f82f8f223f35
Status: Downloaded newer image for xiaowei/hello:latest
[root@ip-172-31-12-155 hello]# uname -i
aarch64
```

至此，我们就完成了同时支持**ARM64**和**x86_64**架构的镜像仓库设置了 ✨✨


## 四、小技巧分享

> 如何制作一个最简单的 hello 镜像

1. 首先要知道我们可以通过一个特殊指令来基于一个空镜像进行构建`FROM scratch`[^7]
2. 编译一个x86的hello程序
```bash

cat << EOF >> hello.c
#include <stdio.h>
int main(void){
  printf("hello");
  return 0;
}
EOF
gcc -o hello -static hello.c
# 如果 gcc 报错 尝试 yum -y install gcc glibc-static
```
3.  编写`Dockerfile`
```bash
cat << EOF >> Dockerfile
From scratch
Add hello /
Entrypoint ["/hello"]
EOF

docker build -t hello .
```

4. 查看镜像，该镜像仅有一层
```bash
[root@iZm5e9qnmldt4il3o1hxf1Z hello]# docker inspect hello | jq '.[0].RootFS'
{
  "Type": "layers",
  "Layers": [
    "sha256:d02b0ff6a0d9b743d718b5e39c891162c3b35624818054b15aefcc0fd7dd07c4"
  ]
}
```

# Ref
> 感谢下列文章的分享

[^1]: [https://github.com/opencontainers/image-spec](https://github.com/opencontainers/image-spec)
[^2]: [https://github.com/moby/moby/blob/master/image/spec/v1.2.md](https://github.com/moby/moby/blob/master/image/spec/v1.2.md)
[^3]: [https://matrix.ai/blog/docker-image-specification-v1-vs-v2/](https://matrix.ai/blog/docker-image-specification-v1-vs-v2/)
[^4]: [https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md](https://github.com/docker/distribution/blob/master/docs/spec/manifest-v2-2.md)
[^5]: [https://docs.docker.com/engine/reference/commandline/cli/#configuration-files](https://docs.docker.com/engine/reference/commandline/cli/#configuration-files)
[^6]: [https://docker_practice.gitee.io/us_en/image/manifest.html](https://docker_practice.gitee.io/us_en/image/manifest.html)
[^7]: [https://docs.docker.com/samples/library/scratch/](https://docs.docker.com/samples/library/scratch/)

本文为©[xiaowei](https://github.com/sharego)原创，基于CC BY-NC-SA 4.0协议公开许可, 2019-08-30