
# 用户开机自动启动程序目录

`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

如`xiaowei`用户： `C:\Users\xiaowei\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`

# 隐藏CMD命令窗口, 是程序后台执行

```bat
@echo off

if "%1"=="h" goto begin

start mshta vbscript:createobject("wscript.shell").run("""%~nx0"" h",0)(window.close)&&exit

:begin

<ourself code>
```

如:

```bat
@echo off

if "%1"=="h" goto begin

start mshta vbscript:createobject("wscript.shell").run("""%~nx0"" h",0)(window.close)&&exit

:begin
d:
D:\green\coredns\coredns.exe -conf D:\green\coredns\Corefile
```