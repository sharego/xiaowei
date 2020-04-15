在 Marathon 的 Docker容器 传递容器进程的启动参数：

## 方法一： 使用 Command

① 使用 `docker inspect image` ， 参看容器镜像的 `Entrypoint` 和 `CMD` 获得 容器启动进程，比如 `/docker-entrypoint.sh` 或 `mysqld_safe`

② 设置 command 为启动进程和进程参数的完整命令数组， 比如 `["/docker-entrypoint.sh", "--args1", "--args2=value"]`


## 方法二： 使用 args (不支持已存在的应用，仅支持新建应用)

① 切换到Marathon应用的JSON 模式

② 将 `"cmd":null`, 这个修改为 参数列表（数组形式）, 比如 `"args": ["--args1", "--args2=value"]`

`cmd`与`args`不能共存