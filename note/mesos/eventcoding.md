# 天宫Mesos Event及Protobuf编程

各类系统都离不开数据的存储和交互，在消息队列被广泛使用、微服务流行的互联网架构体系下，相信大家对事件、数据格式等话题非常感兴趣。Mesos作为天宫资源管理的核心，本文以天宫中Mesos的Event为例，通过`Golang、Java、Python3`三种流行编程语言，介绍Event数据处理和著名的Google Protocol Buffer（简称 `Protobuf`）数据存储格式的工具使用和代码编程。`Protobuf`的完整介绍推荐IBM文章：[Google Protocol Buffer的使用和原理](https://www.ibm.com/developerworks/cn/linux/l-cn-gpb/index.html)和Github上：[Protobuf项目](https://github.com/protocolbuffers/protobuf)。

# 1 简介
>（A）天宫架构中的Mesos是基于开源的[Apache Mesos](http://mesos.apache.org)（简称 `Mesos`），这是 Apache 基金会下顶级开源项目，由`C++`编写的数据中心资源管理系统。以wDRF算法、两级资源调度为核心对数据中心的节点进行资源管理，以达到最合理的资源利用和分布式应用系统的编程模型简化。
>
>Mesos 除提供SDK，也提供了HTTP Endpoints（即HTTP接口），包括Mesos集群事件（即Event），见[https://mesos.apache.org/documentation/latest/endpoints/](https://mesos.apache.org/documentation/latest/endpoints/)。
>
>
>
>关于Mesos详细理论介绍，参见[Mesos论文](https://people.eecs.berkeley.edu/~alig/papers/mesos.pdf)，学习书籍推荐：Mesos In Action，中文译名：Mesos实战。

>（B） [Google Protocol Buffer](https://github.com/protocolbuffers/protobuf) 是 因其跨语言、可扩展性、快速序列化/反序列化、数据大小等各方面的综合优势被大量使用。相对来说，与使用最广泛、用户更熟知的JSON、XML等数据格式相比，几乎无数据可读性。但数据可读性本身并非其目的，Protobuf主要为系统交互而设计，比如[`gRPC`](https://grpc.io/)则默认采用`Protobuf`格式。Protobuf性能测试数据原文在Google Code网站上，该文进行了转载：[https://blog.csdn.net/luyafei_89430/article/details/10739381](https://blog.csdn.net/luyafei_89430/article/details/10739381)， 可以看到Protobuf非常优异的性能表现。


# 2 Mesos Event
> Mesos 在V1版的API 中，通过[Subscribe HTTP Endpoint](https://mesos.apache.org/documentation/latest/operator-http-api/#events)和RecordIO来提供流式的Event事件推送，在传输技术上基于HTTP 长连接（与之相关的技术选型有AJAX 轮询、WebSocket、HTTP/2等）。

Subscribe请求订阅了Mesos集群的事件，在Mesos集群发生变化，如应用启停等都会以动态消息的形式有Mesos Master发送给所有订阅者。而对于订阅者在订阅动作之前，当前的集群情况则会在订阅时全量发送给订阅者，这样客户端即可在一个全量的基础上，通过动态更新来保持集群状况的动态同步。这种方式在增量系统上非常常见。

在本节中介绍基本的Event HTTP传输协议上的定义，Event中Record数据格式

## 2.1 Event 数据格式
Mesos Event数据格式上同时支持`Protobuf`和`JSON`两大主流数据格式。使用非常简单，在发起HTTP请求时设置HTTP的Header： `Content-Type: application/x-protobuf`,`Accept: application/x-protobuf`或 `Content-Type: application/json`,`Accept: application/json`。 Mesos官网要求同时配置 `Message-Accept: application/recordio`。

## 2.2 Event RecordIO
在一个HTTP长连接消息事件订阅中，服务器端会持续推送集群事件，事件数据以Records形式组织，每个Record由record-size LF record-data 三部分组成（即record大小、LF换行符、record数据），其中record大小以十进制数字字面量展示，如一个心跳的record内容为：`20\n{"type":"HEARTBEAT"}`

可见：
1.  第一部分：变长字节的字节数组，表示一个十进制数，如20。Mesos官方建议其数据类型表示为`uint64`，意味着record大小这个部分占用字节数最长为20个字节，最大数为（`2**64=18446744073709551616`）表示此Record数据部分（Record的第三部分）长度为16EiB（32224 PiB），实际上单个事件一般不会超过100MiB（而且用protobuf数据长度会更小），即用普通int/uint类型即可（除c/c++语言中，用long类型来确定最少是4字节）；我们可以称为一个Record的head部分
2. 第二部分：1个字节的换行符\n，ASCII码0x0a
3. 第三部分：变长字节的字节数组，其长度由第一部分指定；我们可以称为一个Record的body部分。

附 BNF 语法描述：
```
    records         = *record

    record          = record-size LF record-data

    record-size     = 1*DIGIT
    record-data     = record-size(OCTET)
```

## 2.3 Request-Response 格式
由于JSON格式文本可读（Protobuf为二进制无法直接展示），此处以JSON为例，展示Event Client 请求格式和 Mesos 返回内容：

```
SUBSCRIBE Request (JSON):

POST /api/v1  HTTP/1.1

Host: mesosmasterhost:5050
Content-Type: application/json
Message-Accept: application/json
Accept: application/json

{
  "type": "SUBSCRIBE"
}

SUBSCRIBE Response Event (JSON):
HTTP/1.1 200 OK

Content-Type: application/json
Transfer-Encoding: chunked

<event-length>
{
  "type": "SUBSCRIBED",
  "subscribed" : {...}
}20\n
{
   "type":"HEARTBEAT"
}
<more events>
``` 

# 3 Protocol Buffer

使用Protocol Buffer和使用JSON最大的区别，JSON为文本协议（类似JSON的二进制协议为[BSON](http://bsonspec.org/)，MongoDB原生支持该格式）且不需要Schema描述数据格式，而Protobuf为二进制协议，所有消息需要有Schema描述才能进行编解码。
>附：不需要Schema描述的协议通常又称为自解释协议或格式，如[MessagePack](https://msgpack.org/)等 ♡这个是我比较喜欢的格式，跨语言传输性能很好♡；采用Schema使用的著名格式有Facebook Thrift*， Apache Avro等；为了更安全的进行JSON数据的校验，JSON也Schema工具加持：[JSON Schema
](http://json-schema.org/) 


也就是在使用Protobuf时，我们需要先写一个Schema对我们的数据格式进行描述，如:
```
syntax = "proto2";

message  Person {
  required string name = 1;
  required int32 id=2;
  optional string email=3;
}
```

在这个Schema中采用的是proto2，这是protobuf的语法版本号，最新版是proto3。

通常Protobuf Schema保存在一到多个proto文件中，有了Schema文件，我们就可以通过`protoc`工具/命令，生成特定编程语言下的代码，进行数据的操作，如序列化和反序列化。

`protoc`可执行文件可在github上下载：[https://github.com/protocolbuffers/protobuf/releases](https://github.com/protocolbuffers/protobuf/releases)， 比如protoc-3.7.1-linux-x86_64.zip 或 protoc-3.7.1-win64.zip 下载后linux系统执行 `chmod a+x protoc`，为便于以后执行将`protoc`移动到`/usr/local/bin`目录下。新版本的protoc命令同时支持兼容编译proto2和proto3的Schema文件。

例如：`protoc --python_out=. person.proto`， 执行完成后即会在当前目录下生成 `person_pb2.py`文件。
>如果运行报错为`protoc: error while loading shared libraries: libatomic.so.1: cannot open shared object file: No such file or directory`， 请安装libatomic，如`yum -y install libatomic`


在Google Developer网站上[https://developers.google.com/protocol-buffers/docs/tutorials](https://developers.google.com/protocol-buffers/docs/tutorials)有以下语言的教程：`C++、C#、Dart、Go、Java、Python`  其他语言一般在相应的Package或Library的介绍中有提供。


# 4 Mesos Event 实战
现在我们基本了解了Mesos Event交互API和数据传输格式，Protoc的使用，终于可以Coding啦，在Coding之前，我们还有一点点小小的环境准备工作，也就是我们需要Mesos的Event Protobuf Schema对不对，还需要一个自己喜欢的编程语言环境，另外还有IDE什么的在本文不描述。

Mesos Event Schema文件在Mesos工程下的`include/mesos/v1/master/master.proto`，该文件引用了另外3个文件`include/mesos/v1/mesos.proto, include/mesos/v1/maintenance/maintenance.proto, include/mesos/v1/quota/quota.proto`。

在`master.proto`文件中Event Request 的 Message名称为 `Call`、返回的Event Response的Message名称为`Event`。对于衣蛾Subscribe Call，目前Mesos返回的Event类型除心跳外，仅有Subscribed、TaskAdd和TaskUpdated三种类型。

## 4.1 准备
* 首先我们需要准备linux（Protobuf支持Windows和macOS，为了方便以Centos Linux为例）
* 准备一份mesos 相关proto文件
* 准备`protobuf`的命令工具`protoc`
* 如果使用`Golang`还需要额外工具, 参见下文
* 所用语言的编译运行环境, 如：JDK、Python3、Node.js等

为了避免github的访问速度，下面采用国内节点提供下载服务。

让我们以Programmer的方式打造该环境吧：
```bash
mkdir ~/mesoseventprotobuf
cd ~/mesoseventprotobuf
# download protoc
curl -O http://120.27.49.85/static/files/dcos/protoc-3.7.1-linux-x86_64.zip
unzip protoc-3.7.1-linux-x86_64.zip
test ! -e /usr/local/bin/protoc && mv bin/protoc /usr/local/bin
test ! -e /usr/local/include/google && mv include/google /usr/local/include
rmdir -rf ~/mesoseventprotobuf/*

# download mesos event proto files
curl -O http://120.27.49.85/static/files/dcos/mesos-event-protos.tgz
tar zxvf mesos-event-protos.tgz
```



## 4.2 Setting & Coding

### 4.2.1 Golang
首先准备Golang的环境，Golang2 还在研发过程中，我们此处我们使用Golang 1.12.3。另外由于protoc工具原生不支持go代码的生成，我们还需要额外安装`protoc-gen-go`, 整个安装如下：
```bash
# 如果go已安装，可以跳过go的安装，注意GOROOT设置
curl -O https://dl.google.com/go/go1.12.3.linux-amd64.tar.gz
tar zxf go1.12.3.linux-amd64.tar.gz
mv go /usr/local/go-1.12.3
ln -s /usr/local/go-1.12.3 /usr/local/go
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin

# 安装 protoc-gen-go
mkdir -p ~/mesoseventprotobuf/go/src
cd ~/mesoseventprotobuf
export GOPATH=$HOME/mesoseventprotobuf/go
go get -u github.com/golang/protobuf/protoc-gen-go
cp protoc-gen-go /usr/local/bin

# 根据proto文件生成Event消息的Golang代码
find include -type f -name "*.proto" | xargs -n1 protoc -Iinclude --go_out=./go/src
cd ~/mesoseventprotobuf/go/src
```
**然后就可以开始愉快的Coding啦**
代码见：
```go
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"github.com/golang/protobuf/proto"
	mesos "mesos/v1/master"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

func main() {
	mesosUrl := "http://10.211.55.6:5050/api/v1"

	if len(os.Args) > 1 && len(strings.TrimSpace(os.Args[1])) > 0 {
		mesosUrl = strings.TrimSpace(os.Args[1])
	}

	subscribedCall := &mesos.Call{Type: mesos.Call_SUBSCRIBE.Enum()}

	requestPayload, _ := proto.Marshal(subscribedCall)

	fmt.Printf("%s we subscribe the mesos: %s\n", time.Now().Format("2006-01-02 15:04:05"), mesosUrl)

	req, _ := http.NewRequest("POST", mesosUrl, bytes.NewReader(requestPayload))

	req.Header.Set("Content-Type", "application/x-protobuf")
	req.Header.Set("Accept", "application/x-protobuf")
	req.Header.Set("Message-Accept", "application/recordio")

	res, _ := http.DefaultClient.Do(req)

	defer func() {
		if res != nil {
			res.Body.Close()
		}
	}()

	buf := bufio.NewReaderSize(res.Body, 104857600) // 100MiB Just a Example

	recordQueue := make(chan []byte, 10)

	go recordProcess(recordQueue)

	for i := 0; i < 10; i++ {

		record, err := readRecord(buf)
		if err != nil {
			fmt.Println("read record failed: ", err)
			break
		}

		fmt.Printf("\n%s get the %d record, length: %d\n",
			time.Now().Format("2006-01-02 15:04:05"), i, len(record))
		recordQueue <- record

		time.Sleep(100 * time.Millisecond) // sleep 0.1s
	}

	close(recordQueue)

}

// goroutine process each record
func recordProcess(ch chan []byte) {
	for {
		record, ok := <-ch
		if !ok {
			break
		}
		handleEventRecord(record)
	}
}

func handleEventRecord(data []byte) {

	// parse record binary data to event object
	event := &mesos.Event{}
	err := proto.Unmarshal(data, event)
	if err != nil {
		fmt.Println("Parse protobuf data Failed: ", err)
		return
	}

	// do something for this event
	et := event.GetType().String()

	fmt.Println("This is a " + et + " Event")

	switch event.GetType() {
	case mesos.Event_SUBSCRIBED:
		showSubscribedEvent(event)
		break
	case mesos.Event_TASK_ADDED:
		showTaskAddedEvent(event)
		break
	case mesos.Event_TASK_UPDATED:
		showTaskUpdatedEvent(event)
		break
	}

}

func showSubscribedEvent(e *mesos.Event) {
	s := e.GetSubscribed().GetGetState()
	fmt.Printf("The cluster has %v agents, %v frameworks, %v tasks\n",
		len(s.GetGetAgents().GetAgents()),
		len(s.GetGetFrameworks().GetFrameworks()),
		len(s.GetGetTasks().GetTasks()))
}

func showTaskAddedEvent(e *mesos.Event) {
	task := e.GetTaskAdded().GetTask()
	fmt.Printf("A new task %v was %v \n", *(task.TaskId.Value),
		task.State)
}

func showTaskUpdatedEvent(e *mesos.Event) {
	update := e.GetTaskUpdated()
	fmt.Printf("The task %v was %v \n", *(update.GetStatus().TaskId.Value),
		update.GetState())
}

func readRecord(buf *bufio.Reader) ([]byte, error) {

	// first we read the first part of the record, it ends with a LF
	head, err := buf.ReadBytes('\n')
	if err != nil {
		return nil, err
	}

	length, err := strconv.Atoi(strings.TrimSpace(string(head)))
	if err != nil {
		return nil, err
	}

	// then we read the third part of the record, it has a mixed size
	data, err := buf.Peek(length)

	if err == nil {
		buf.Discard(length)
	}

	return data, err
}

```
然后执行： `go run eventdemo.go [mesosurl]`




### 4.2.2 Java
首先准备Java的环境，需要Java JDK，为了减少Maven使用，直接下载jar，不用Maven工程。另外，此处采用Java 11 提供的HttpClient，而非Java8中常用的Apache HttpClient包。安装如下
```bash
# 安装Java11
yum -y install java-11-openjdk java-11-openjdk-devel
mkdir -p ~/mesoseventprotobuf/java/bin
cd ~/mesoseventprotobuf
curl -O http://central.maven.org/maven2/com/google/protobuf/protobuf-java/3.7.1/protobuf-java-3.7.1.jar
# 根据Proto文件生成Event消息Java代码
find include -type f -name "*.proto" | xargs protoc -Iinclude --java_out=./java
```
**Coding**
代码见：
```java
package eventdemo;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpRequest.BodyPublishers;
import java.net.http.HttpResponse;
import java.net.http.HttpResponse.BodyHandlers;
import java.nio.ByteBuffer;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.function.Consumer;

import org.apache.mesos.v1.master.Protos;
import org.apache.mesos.v1.master.Protos.Event;
import org.apache.mesos.v1.master.Protos.Response.GetState;

/**
 * MESOS Event Demo With PROTOBUF, New HttpClient API In Java11
 * 
 * @author xiaowei
 *
 */
public class EventDemo {
	private String mesosUrl;

	public EventDemo(String mesosUrl) {
		this.mesosUrl = mesosUrl;
	}

	public void callMesos() {

		Protos.Call subscribedCall = Protos.Call.newBuilder()
				.setType(Protos.Call.Type.SUBSCRIBE).build();
		byte[] payload = subscribedCall.toByteArray();

		HttpClient client = HttpClient.newHttpClient();

		HttpRequest request = HttpRequest.newBuilder().uri(URI.create(mesosUrl))
				.timeout(Duration.ofMinutes(2))
				.header("Content-Type", "application/x-protobuf")
				.header("Accept", "application/x-protobuf")
				.header("Message-Accept", "application/recordio")
				.POST(BodyPublishers.ofByteArray(payload)).build();

		final EventDemo ed = this;

		client.sendAsync(request, BodyHandlers.ofInputStream())
				.thenApply(HttpResponse::body)
				.thenAccept(new Consumer<InputStream>() {

					@Override
					public void accept(InputStream in) {

						ByteBuffer buffer = ByteBuffer.allocate(104857600); // 100MiB

						try {

							for (int i = 0; i < 10; i++) {
								buffer.clear();
								ed.readRecord(in, buffer);
								System.out.printf(
										"\n%s we get the %d record, length of: %s\n",
										LocalDateTime.now(), i, buffer.limit());
								Event ev = ed.parseRecord(buffer);
								if (ev != null) {
									ed.handleEvent(ev);
								}

								try {
									Thread.sleep(100);
								} catch (InterruptedException e) {
								}

							}

						} catch (IOException e) {
							e.printStackTrace();
						}

					}

				}).join();

	}

	protected void handleEvent(Event e) {
		showEvent(e);
	}

	public void showEvent(Event e) {
		System.out.println("This is a " + e.getType() + " Event");
		switch (e.getType().getNumber()) {
		case Event.Type.SUBSCRIBED_VALUE:
			showSubscribedEvent(e);
			break;
		case Event.Type.TASK_ADDED_VALUE:
			showTaskAddedEvent(e);
			break;
		case Event.Type.TASK_UPDATED_VALUE:
			showTaskUpdatedEvent(e);
			break;
		}

	}

	public void showSubscribedEvent(Event e) {
		String showtpl = "The cluster has %s agents, %d frameworks, %s tasks\n";
		GetState state = e.getSubscribed().getGetState();
		System.out.printf(showtpl, state.getGetAgents().getAgentsCount(),
				state.getGetFrameworks().getFrameworksCount(),
				state.getGetTasks().getTasksCount());

	}

	public void showTaskAddedEvent(Event e) {
		System.out.printf("A new task %s was %s\n",
				e.getTaskAdded().getTask().getTaskId().getValue(),
				e.getTaskAdded().getTask().getState());
	}

	public void showTaskUpdatedEvent(Event e) {
		System.out.printf("The task %s was %s\n",
				e.getTaskUpdated().getStatus().getTaskId().getValue(),
				e.getTaskUpdated().getState());
	}

	protected Event parseRecord(ByteBuffer buffer) throws IOException {
		return Event.parseFrom(buffer);
	}

	protected ByteBuffer readRecord(InputStream in, ByteBuffer buffer)
			throws IOException {

		// first read head of the record
		for (int i = 0; i < 20; i++) {
			int b = in.read();
			if (b != '\n') {
				buffer.put((byte) b);
			} else {
				break;
			}
		}

		if (buffer.position() == 20) {
			throw new IOException("can not find record second part, the `LF` Character: " + new String(buffer.array(), 0, buffer.position()));
		}

		// then read the third of the record
		int recordBodySize = Integer
				.parseInt(new String(buffer.array(), 0, buffer.position()));

		if (recordBodySize <= 0 || recordBodySize > buffer.capacity()) {
			throw new IOException(
					"record data, length error: " + recordBodySize);
		}
		buffer.clear();
		int read = in.readNBytes(buffer.array(), 0, recordBodySize);
		if (read != recordBodySize) {
			throw new IOException("record data not enough, need "
					+ recordBodySize + ", only have: " + read);
		}
		buffer.position(0);
		buffer.limit(recordBodySize);
		return buffer;
	}

	public static void main(String[] args) {

		String url = "http://10.0.209.3:5050/api/v1";
		if (args.length > 1) {
			url = args[1];
		}

        System.out.printf("%s we subscribe the mesos: %s\n", LocalDateTime.now(), url);
		EventDemo me = new EventDemo(url);

		me.callMesos();

	}

}
```
然后编译执行:
```bash
# compile 
find org -type f -name "*.java" -exec javac -cp .:protobuf-java-3.7.1.jar -d `pwd`/bin {} \;
javac -cp .:protobuf-java-3.7.1.jar:bin -d bin EventDemo.java
# run
java -cp bin:protobuf-java-3.7.1.jar EventDemo [mesosurl]
```


### 4.2.3 Python3
首先准备Python环境，Python有两个主要的版本，此处采用`python3`，安装如下：

```
yum -y insall python36 python36-pip
pip3 install protobuf requests
mkdir ~/mesoseventprotobuf/python
cd ~/mesoseventprotobuf

# 根据Proto文件生成Event消息Python代码
find include -type f -name "*.proto" | xargs protoc -Iinclude --python_out=./python
cd python
```


**Coding**

```python
#!/usr/bin/python3

#author: xiaowei

import time
from datetime import datetime
import requests
from mesos.v1.master import master_pb2
from mesos.v1 import mesos_pb2


HEADERS = {
    'Content-Type': "application/x-protobuf",
    'Accept': "application/x-protobuf",
    'Message-Accept': "application/recordio",
    'cache-control': "no-cache",
}


class MesosEvent(object):

    def __init__(self, mesosurl):
        self.url = mesosurl

    def call_mesos(self):
        print('%s we subscribe the mesos: %s' %
              (datetime.now().isoformat(' '), self.url))
        subscribed = master_pb2.Call()
        subscribed.type = master_pb2.Call.SUBSCRIBE

        payload = subscribed.SerializeToString()

        self.res = requests.request(
            "POST", self.url, data=payload, headers=HEADERS, stream=True, timeout=(3, 120), )

        try:
            self._api_handle()
        finally:
            if self.res is not None:
                self.res.close()

    def _api_handle(self):
        for i in range(10):  # 此处我们只读取10个Record, 然后结束
            record = self._read_record()
            if record is not None:
                print('\n%s get the %d record, length: %s' %
                      (datetime.now().isoformat(' '), i, len(record)))
                event = self._parse_record(record)
                if event is not None:
                    self._handle_event(event)

    def _handle_event(self, e):
        self.show_event(e)

    def _parse_record(self, r):
        e = master_pb2.Event()
        try:
            e.ParseFromString(r)
        except:
            print(r)
            raise

        return e

    def _read_record(self):
        r = self.res.raw

        # now read record first part, we call it head of record

        head = bytearray()
        pos = -1
        while len(head) < 21:
            # a HEARTBEAT record total size is 4 bytes: 1 byte of the 1st part, 1 byte of LF, 2 bytes of the 3rd part
            # so we only read 4 bytes each time, otherwise we will maybe read more than two records
            data = r.read(4)
            if not data:  # no data, maybe we need wait
                time.sleep(0.1)
                continue
            head.extend(data)
            pos = head.find(b'\n')
            if pos > 0:
                break

        if pos > 0:
            record_body_len = int(head[:pos])
        else:
            raise IOError(
                'can not find record second part, the `LF` Character: ' + str(head))

        # now read record third part, we call it body of record

        if record_body_len <= 0 or record_body_len > 1073741824:  # we assume record body less than 1GiB
            raise ValueError('record data, length error: ' + str(head))

        if pos < len(head) - 1:
            body_remain_read = record_body_len - len(head) + pos + 1
        else:
            body_remain_read = record_body_len

        body = r.read(body_remain_read)
        if body_remain_read < record_body_len:
            body = head[pos+1:] + body

        return body

    def show_event(self, e):

        et = master_pb2.Event.Type.Name(e.type)
        print("This is a %s event" % (et, ))

        if hasattr(self, '_show_event_' + et.lower()):
            getattr(self, '_show_event_' + et.lower())(e)

    def _show_event_subscribed(self, e):
        showtpl = '''The cluster has %s agents, %d frameworks, %s tasks\n'''
        s = e.subscribed.get_state
        print(showtpl % (len(s.get_agents.agents), len(
            s.get_frameworks.frameworks), len(s.get_tasks.tasks)))

    def _show_event_task_added(self, e):
        a = e.task_added
        print('A new task %s was %s ' %
              (a.task.task_id.value, mesos_pb2.TaskState.Name(a.task.state)))

    def _show_event_task_updated(self, e):
        u = e.task_updated
        print('The task %s was %s ' %
              (u.status.task_id.value, mesos_pb2.TaskState.Name(u.state)))

if __name__ == '__main__':
    if len(sys.argv) > 1 and len(sys.argv[1].strip()) > 0:
        mesosurl = sys.argv[1].strip()
    else:
        mesosurl = "http://10.211.55.6:5050/api/v1"
    MesosEvent(mesosurl).call_mesos()

```
然后执行： `python3 eventdemo.py [mesosurl]`



## 5 后记
至此，Mesos Event的读取和开源Protobuf的在上述编程语言的基本使用，有了解。对于Event长链接的正确处理，如异常断开重连、数据异常检测、等待超时、数据的流式处理、链接断开导致缓存溢出等在生产系统中都需要考虑并处理，比如上面的Example都没有对HTTP Status Code做检测。

# Ref
[Apache Mesos](https://mesos.apache.org/documentation/latest)
[Golang](https://golang.google.cn)
[python requests](http://cn.python-requests.org/zh_CN/latest/)
[python urllib3](https://urllib3.readthedocs.io)
[国内Protobuf性能转载 luyafei CSDN Blog](https://blog.csdn.net/luyafei_89430/article/details/10739381)

注：Facebook Thrift，已捐献给Apache，是Apache顶级项目。

本文为©[xiaowei](https://github.com/sharego)原创，基于[**CC BY-NC-SA 4.0**](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh)协议公开许可, 2019-05-08
