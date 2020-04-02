
# init

Doc Site: https://containerd.io/downloads/

Install:

```bash

wget https://github.com/containerd/containerd/releases/download/v1.3.2/containerd-1.3.2.linux-amd64.tar.gz
tar xvf containerd-1.3.2.linux-amd64.tar.gz
mv bin/* /usr/local/bin
wget https://github.com/containerd/containerd/raw/master/containerd.service
mv containerd.service /etc/systemd/system
mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl daemon-reload
systemctl start containerd

```

Downloads: `wget https://github.com/containerd/containerd/releases/download/v1.3.2/containerd-1.3.2.linux-amd64.tar.gz`



