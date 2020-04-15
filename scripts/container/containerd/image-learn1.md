

# 1. 镜像OCI 标准

从Open Container Initiative组织成立后，Docker Image Schema V2 成为了 OCI Image 的标准规范，规范内容参见：https://github.com/opencontainers/image-spec/blob/master/spec.md （注意：V1与OCI标准不一致）

在规范中，定义了容器镜像的4部分组成：一个manifest（清单文件），一个image index（可选，又称manifest list、fat manifest），一个filesystem layers集合，和一个configuration（配置文件）.

* Image Manifest - a document describing the components that make up a container image （主要包含config文件和layers digest列表，json格式）
* Image Index - an annotated index of image manifests （一个支持多平台platform的manifest的列表，json格式）
* Image Configuration - a document determining layer ordering and configuration of the image suitable for translation into a runtime bundle （容器镜像到容器的配置最完整的描述信息, json格式）
* Filesystem Layer - a changeset that describes a container's filesystem（layer文件集，一般是 .tar.gz 格式，但无后缀）

注意在Manifest中的layers可以是Filesystem Layer也可以是Image Layerout, 具体看MediaType
* Image Layout - a filesystem layout representing the contents of an image

通过`docker save -o alpine.tar alpine` 命令可以得到一个容器镜像文件，解压，即可查看Image Layout结构

## 1.1. 下载容器镜像

下载容器镜像，可以通过很多客户端或工具完成, 比如 `docker`、`ctr` 或 `podman`, 但也可以通过 `curl`完成, 以 alpine:latest 为例:

```bash
# 1 获取hub.docker.com 的 Token
echo -n 'Username:Password' | base64 # 将计算结果替换下面Basic后的xxxx
export token=`curl -qsL -X GET -H 'Authorization: Basic xxxx' -H 'Content-Type: application/json' 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull' | jq '.token' -r`


# 2 用得到的Token 调用 docker hub的api, 注意使用 `registry.hub.docker.com` [^2]

## 2.1 获取 index文件
curl -qsL -X GET -H "Authorization: Bearer $token" -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' https://registry.hub.docker.com/v2/library/alpine/manifests/latest -o index.json

## 2.2 根据index文件, 获取 manifest文件
curl -qsL -X GET -H "Authorization: Bearer $token" https://registry.hub.docker.com/v2/library/alpine/manifests/sha256:cb8a924afdf0229ef7515d9e5b3024e23b3eb03ddbba287f4a19c6ac90b8d221 -o manifest.json
### or
curl -qsL -X GET -H "Authorization: Bearer $token" -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://registry.hub.docker.com/v2/library/alpine/manifests/latest -o manifest.json

### 从manifest文件得到config和layers信息

## 2.3 获取 Config 文件
curl -qsL -X GET -H "Authorization: Bearer $token"  https://registry.hub.docker.com/v2/library/alpine/blobs/sha256:a187dde48cd289ac374ad8539930628314bc581a481cdb41409c9289419ddb72 -o config.json

## 2.4 获取 layer文件
curl -qsL -X GET -H "Authorization: Bearer $token"  https://registry.hub.docker.com/v2/library/alpine/blobs/sha256:aad63a9339440e7c3e1fff2b988991b9bfb81280042fa7f39a5e327023056819 -o layers.tar.gz

```
Token API 参考[^1], Registry API参考[^2]

可以看到与ctr下载的一致，如下图:
```bash
root@10-255-0-179 /v/l/c/f# ctr image pull --snapshotter overlayfs docker-hub.didiyun.com/library/alpine:latest
docker-hub.didiyun.com/library/alpine:latest:                                     resolved       |++++++++++++++++++++++++++++++++++++++|
index-sha256:b276d875eeed9c7d3f1cfa7edb06b22ed22b14219a7d67c52c56612330348239:    done           |++++++++++++++++++++++++++++++++++++++|
manifest-sha256:cb8a924afdf0229ef7515d9e5b3024e23b3eb03ddbba287f4a19c6ac90b8d221: done           |++++++++++++++++++++++++++++++++++++++|
layer-sha256:aad63a9339440e7c3e1fff2b988991b9bfb81280042fa7f39a5e327023056819:    done           |++++++++++++++++++++++++++++++++++++++|
config-sha256:a187dde48cd289ac374ad8539930628314bc581a481cdb41409c9289419ddb72:   done           |++++++++++++++++++++++++++++++++++++++|
elapsed: 2.9 s                                                                    total:   0.0 B (0.0 B/s)
unpacking linux/amd64 sha256:b276d875eeed9c7d3f1cfa7edb06b22ed22b14219a7d67c52c56612330348239...
done
```

# 2. Containerd 镜像存储

## 2.1. 准备数据库查看工具
> 注意查看时, 需要先停止 containerd
```
# 使用已经编译好的

wget https://tools.xwsea.com/static/bolter.gz

# 工具来源 (go项目，自行编译即可)

https://github.com/hasit/bolter

```

## 2.2. Image 元数据存储 (metadata)

默认配置下，所有存储的镜像不区分snapshotter，都统一存储在`/var/lib/containerd/io.containerd.metadata.v1.bolt/meta.db` 文件中

> 数据格式可以参考：https://github.com/containerd/containerd/blob/d25007e548c08eb16712381fdb1b727b1ffb50ea/metadata/buckets.go#L48

我们可以用`bolter -f /var/lib/containerd/io.containerd.metadata.v1.bolt/meta.db` 查看该文件(数据库)内容

如`ctr images ls`中镜像为：
```bash
root@10-255-0-179 /v/l/containerd# ctr image ls
REF                                           TYPE                                                      DIGEST                                                                  SIZE      PLATFORMS                                                                                              LABELS
docker-hub.didiyun.com/library/busybox:latest application/vnd.docker.distribution.manifest.list.v2+json sha256:89b54451a47954c0422d873d438509dae87d478f1cb5d67fb130072f67ca5d25 746.8 KiB linux/386,linux/amd64,linux/arm/v5,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/s390x  -
docker.io/library/alpine:latest               application/vnd.docker.distribution.manifest.list.v2+json sha256:b276d875eeed9c7d3f1cfa7edb06b22ed22b14219a7d67c52c56612330348239 2.7 MiB   linux/386,linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/s390x               -
docker.io/library/hello-world:latest          application/vnd.docker.distribution.manifest.list.v2+json sha256:f9dfddf63636d84ef479d645ab5885156ae030f611a56f3a7ac7f2fdd86d7e4e 4.8 KiB   linux/386,linux/amd64,linux/arm/v5,linux/arm/v7,linux/arm64/v8,linux/ppc64le,linux/s390x,windows/amd64 -
```
则文件中Image对应的key和value为：
```bash
Query: v1 >> default >> images

Bucket: images
+------------------------------------------------+-------+
|                      KEY                       | VALUE |
+------------------------------------------------+-------+
| docker-hub.didiyun.com/library/busybox:latest* |       |
| docker.io/library/alpine:latest*               |       |
| docker.io/library/hello-world:latest*          |       |
+------------------------------------------------+-------+
```
> `*` 表示此处不是叶子节点，可以继续deep explorer

继续查看 `docker-hub.didiyun.com/library/busybox:latest` 下的 `target` 中 `digest` key, 得到镜像的manifest list id（注意：manifest list是可选项，一个镜像可以只有manifest，没有manifest list）`sha256:89b54451a47954c0422d873d438509dae87d478f1cb5d67fb130072f67ca5d25`

通过查看 `io.containerd.content.v1.content/blobs/sha256/89b54451a47954c0422d873d438509dae87d478f1cb5d67fb130072f67ca5d25` 这manifest list(又称Image Index) JSON文件，获得manifest列表内容，内容如下(省略大部分platform)：
```bash
{
  "manifests": [
    {
      "digest": "sha256:a2490cec4484ee6c1068ba3a05f89934010c85242f736280b35343483b2264b6",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "amd64",
        "os": "linux"
      },
      "size": 527
    },
    {
      "digest": "sha256:6810b7a2db85d3f0d0717b54a97b73e721e2b8a22d42f8a5d91f714b06e77de6",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "arm",
        "os": "linux",
        "variant": "v5"
      },
      "size": 527
    }
  ],
  "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
  "schemaVersion": 2
}
```

查找符合当前platform（即当前主机对应的os和cpu architecture），得到一个manifest 文件的digest, `sha256:a2490cec4484ee6c1068ba3a05f89934010c85242f736280b35343483b2264b6`

### 2.2.1. 镜像内容

查看 `io.containerd.content.v1.content/blobs/sha256/a2490cec4484ee6c1068ba3a05f89934010c85242f736280b35343483b2264b6`文件，得到manifest内容，主要包含两部分：config和layers, 内容如下：
```bash
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
  "config": {
    "mediaType": "application/vnd.docker.container.image.v1+json",
    "size": 1494,
    "digest": "sha256:be5888e67be651f1fbb59006f0fd791b44ed3fceaa6323ab4e37d5928874345a"
  },
  "layers": [
    {
      "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
      "size": 760854,
      "digest": "sha256:e2334dd9fee4b77e48a8f2d793904118a3acf26f1f2e72a3d79c6cae993e07f0"
    }
  ]
}
```

查看config文件：`io.containerd.content.v1.content/blobs/sha256/be5888e67be651f1fbb59006f0fd791b44ed3fceaa6323ab4e37d5928874345a`

获得`rootfs`、镜像构建历史、环境变量等等容器的配置信息，此部分内容在`docker`中可以通过`docker inspect image_name`查看
```bash
  "rootfs": {
    "type": "layers",
    "diff_ids": [
      "sha256:5b0d2d635df829f65d0ffb45eab2c3124a470c4f385d6602bda0c21c5248bcab"
    ]
  }
```
这个rootfs的信息则存储在`containerd`的元数据`io.containerd.metadata.v1.bolt/meta.db` 和 对应的`snapshotter plugin`的元数据中`devmapper/metadata.db`, 如下图
```bash
# bolter -f io.containerd.metadata.v1.bolt/meta.db
Query: v1 >> default >> snapshots >> devmapper

Bucket: devmapper
+--------------------------------------------------------------------------+-------+
|                                   KEY                                    | VALUE |
+--------------------------------------------------------------------------+-------+
| sha256:5b0d2d635df829f65d0ffb45eab2c3124a470c4f385d6602bda0c21c5248bcab* |       |
| sha256:af0b15c8625bb1938f1d7b17081031f649fd14e6b233688eea3c5483994a66a3* |       |
| sha256:beee9f30bc1f711043e78d4a2be0668955d4b761d587d6f60c2c8dc081efb203* |       |
+--------------------------------------------------------------------------+-------+
```

```
# bolter -f devmapper/metadata.db
Query: v1 >> snapshots

Bucket: snapshots
+------------------------------------------------------------------------------------+-------+
|                                        KEY                                         | VALUE |
+------------------------------------------------------------------------------------+-------+
| default/2/sha256:af0b15c8625bb1938f1d7b17081031f649fd14e6b233688eea3c5483994a66a3* |       |
| default/4/sha256:beee9f30bc1f711043e78d4a2be0668955d4b761d587d6f60c2c8dc081efb203* |       |
| default/6/sha256:5b0d2d635df829f65d0ffb45eab2c3124a470c4f385d6602bda0c21c5248bcab* |       |
+------------------------------------------------------------------------------------+-------+
```

而镜像中的layers文件同样也是存储在改目录下`io.containerd.content.v1.content/blobs/sha256/e2334dd9fee4b77e48a8f2d793904118a3acf26f1f2e72a3d79c6cae993e07f0`, 该文件构建了一个完整的文件系统. 使用`tar -zxf io.containerd.content.v1.content/blobs/sha256/e2334dd9fee4b77e48a8f2d793904118a3acf26f1f2e72a3d79c6cae993e07f0` 可以解压查看该文件系统内容

> **此时可以结论** 镜像文件初始数据的存储，对于不同的snapshotter是同一份, 但不同snapshotter对解压后的layer文件管理不一样

### 2.2.2. 镜像下载过程
也可以通过不同snapshotter下载同一镜像镜像验证:
```bash
root@10-255-0-179 /v/l/containerd# ctr image pull --snapshotter overlayfs docker-hub.didiyun.com/library/alpine:3.4
docker-hub.didiyun.com/library/alpine:3.4:                                        resolved       |++++++++++++++++++++++++++++++++++++++|
index-sha256:b733d4a32c4da6a00a84df2ca32791bb03df95400243648d8c539e7b4cce329c:    done           |++++++++++++++++++++++++++++++++++++++|
manifest-sha256:0325f4ff0aa8c89a27d1dbe10b29a71a8d4c1a42719a4170e0552a312e22fe88: done           |++++++++++++++++++++++++++++++++++++++|
layer-sha256:c1e54eec4b5786500c19795d1fc604aa7302aee307edfe0554a5c07108b77d48:    done           |++++++++++++++++++++++++++++++++++++++|
config-sha256:b7c5ffe56db790f91296bcebc5158280933712ee2fc8e6dc7d6c96dbb1632431:   done           |++++++++++++++++++++++++++++++++++++++|
elapsed: 18.5s                                                                    total:  2.3 Mi (124.6 KiB/s)
unpacking linux/amd64 sha256:b733d4a32c4da6a00a84df2ca32791bb03df95400243648d8c539e7b4cce329c...
done
root@10-255-0-179 /v/l/containerd#
root@10-255-0-179 /v/l/containerd# ctr image pull --snapshotter devmapper docker-hub.didiyun.com/library/alpine:3.4
docker-hub.didiyun.com/library/alpine:3.4:                                        resolved       |++++++++++++++++++++++++++++++++++++++|
index-sha256:b733d4a32c4da6a00a84df2ca32791bb03df95400243648d8c539e7b4cce329c:    done           |++++++++++++++++++++++++++++++++++++++|
manifest-sha256:0325f4ff0aa8c89a27d1dbe10b29a71a8d4c1a42719a4170e0552a312e22fe88: done           |++++++++++++++++++++++++++++++++++++++|
layer-sha256:c1e54eec4b5786500c19795d1fc604aa7302aee307edfe0554a5c07108b77d48:    done           |++++++++++++++++++++++++++++++++++++++|
config-sha256:b7c5ffe56db790f91296bcebc5158280933712ee2fc8e6dc7d6c96dbb1632431:   done           |++++++++++++++++++++++++++++++++++++++|
elapsed: 10.2s                                                                    total:   0.0 B (0.0 B/s)
unpacking linux/amd64 sha256:b733d4a32c4da6a00a84df2ca32791bb03df95400243648d8c539e7b4cce329c...
done
```


# 3. Ref

[^1]: [https://docs.docker.com/registry/spec/auth/token/](https://docs.docker.com/registry/spec/auth/token/)

[^2]: [https://docs.docker.com/registry/spec/api/](https://docs.docker.com/registry/spec/api/)
