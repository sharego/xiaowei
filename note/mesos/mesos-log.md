
# 1. mesos log 管理方式

## 1.1. mesos log 形式

mesos 采用 google glog（cpp）库进行日志管理，代码中日志输出形式有三种：
* LOG(INFO)
* PLOG(FATAL)
* VLOG(2)

### 1.1.1. LOG 宏
这个是标准的日志输出，也是glog框架默认的日志使用形式，日志级别仅有四种：
* 0 INFO 或 GLOG_INFO
* 1 WARNING
* 2 ERROR
* 3 FATAL
参见代码： https://github.com/google/glog/blob/3267f3e1a8dd629922dbe28c09a5fa5e60de5a84/src/windows/glog/log_severity.h#L51

在Mesos中这个日志级别默认由进程启动命令行参数logging_level控制，仅支持INFO、WARNING、ERROR三个级别的配置，详见代码： https://github.com/apache/mesos/blob/25941b00377e13a5e6040819184a46bb29390661/src/logging/logging.cpp#L409


### 1.1.2. VLOG 宏

这个是glog库提供一套用于自定义管理级别的日志方式，一般称为*verbose_logging*, 日志级别为`int32`型，基本无限制。因此，一般用数字表示。

在mesos中，verbos logging 做了代码规范上的定义，规定必须使用数字形式，不能使用`INFO`、`WARNNING`这样的宏定义，参见： https://github.com/apache/mesos/blob/master/support/cpplint.py#2150

根据代码搜索，在mesos中使用了`VLOG(1)`、`VLOG(2)`、`VLOG(3)` 这三种级别, mesos启动时默认verbose_level是0，即不打印任何 verbose日志，`#define VLOG_IS_ON(verboselevel) (FLAGS_v >= (verboselevel))`, 参见代码：https://github.com/google/glog/blob/3267f3e1a8dd629922dbe28c09a5fa5e60de5a84/src/glog/vlog_is_on.h.in#L93

> **启用`VLOG`**

1. 方式一：通过环境变量`GLOG_v`传递相应的值，在进程启动时指定`verboselevel`的级别, 在Mesos中默认是0，表示不输出, 根据glog, vmodule参数可以覆盖相关配置。

2. 方式二：在Mesos中，还可以通过调用mesos的api, 动态设置, 参见：http://mesos.apache.org/documentation/latest/endpoints/logging/toggle 如
```bash
# 查询当前verbose log的level
curl http://10.124.142.222:5050/logging/toggle

# 修改verbos log level
curl -X POST 'http://10.124.142.222:5050/logging/toggle?level=2&duration=2mins'

level为2，表示输出 `VLOG(1)` 和 `VLOG(2)`， 其中`VLOG(3)`大于配置的值，不输出
duration 表示的持续时间过之后，level会自动的回到0, 关闭 verbose log

```

### 1.1.3. PLOG 宏

PLOG 是 glog 对 `perror`的一个封装， 一般来说使用PLOG 都是 PLOG(FATAL)级别

## 1.2. Debug

glog中还提供了一个`DLOG`宏，用于`debug log`的控制输出，在mesos中没有使用。

Mesos没有提供全局级别的debug，在1.9中新增了容器的debug api: `/containerizer/debug`, 详见：http://mesos.apache.org/documentation/latest/endpoints/slave/containerizer/debug/