# 下载方式
> git clone https://github.com/2170330798/install-kubernetes.git
# 使用方式
###
1.下载完了之后修改下面的内容,替换成你自己设计的
```
#================================================
#set base info
#================================================
HOST="192.168.10.192"
MASK="24"
GetWay="192.168.10.2"
DnsServers="8.8.8.8, 114.114.114.114"

VERSION="1.28.2"
NAME="k8-master-04"
DockerHub="registry.docker.io:5000"
DockerHubIp="10.10.6.204"

INTERFACE="ens33"
```
2.确保网卡名字正确,以及这个网络配置文件是否存在
```
#================================================
#set network
#sudo vim /etc/netplan/50-cloud-init.yaml
#================================================
if  [ -f  "/etc/netplan/50-cloud-init.yaml" ];then
  echo  "文件存在"
else
  echo  "文件不存在"
  sudo  touch /etc/netplan/50-cloud-init.yaml
fi

sudo cat <<EOF> /etc/netplan/50-cloud-init.yaml
   network:
      version: 2
      renderer: networkd
      ethernets:
        ${INTERFACE}:
          dhcp4: no
          addresses: [${HOST}/${MASK}]
          routes:
            - to: default
              via: ${GetWay}
          nameservers:
            addresses: [${DnsServers}]
EOF

sudo netplan apply
```
3.如果以上确保完毕则执行脚本
```
sudo bash install-k8s-master
sudo bash install-k8s-slave

#Then you can join any number of worker nodes by running the following on each as root:
#修改/etc/kubernetes所有者
chown k8-slave-01:k8-slave-02 /etc/kubernetes
#加入之前需要把master节点的admin.conf文件复制一份到slave节点
scp ubuntu@10.10.6.204:/etc/kubernetes/admin.conf /etc/kubernetes#大概率报错操作不被允许

#子节点加入cluster集群,用你自己master节点的token加入
kubeadm join 192.168.135.132:6443 --token abcdef.0123456789abcdef \
        --discovery-token-ca-cert-hash sha256:fb79dc6cc4b46871635c8f6195a418d464a018b8c06f39b497649a35342555f4 

```
