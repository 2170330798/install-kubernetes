#! /bin/bash
#本文档使用kubeadm安装kubernetes Version: 1.28.2
#Copyright@2025-1-25
#Wrote by JunXiTang
#===============================================
#Notice: 
#   OS: Ubuntu20.04~22.04
#   Kubernets: v1.28.0~v1.30.2
#   Containerd: v1.7.12
#   Calico: v3.29.1
#===============================================

export HOST="10.10.8.108"
export MASK="24"
export GetWay="10.10.8.1"
export DnsServers="8.8.8.8, 114.114.114.114"

export VERSION="1.28.2"
export NAME="k8-slave-01"
export DockerHub="registry.docker.io:5000"
export DockerHubIp="10.10.6.204"

#export HOST0="10.10.8.107"
#export NAME0="k8-master-01"

#================================================
#set hosts
#sudo vim /etc/hosts
#================================================
#sudo sed -i "$ a ${HOST}  ${NAME}"  /etc/hosts
sudo sed -i "$ a ${DockerHubIp}  ${DockerHub::-5}"  /etc/hosts
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup
sudo touch /etc/apt/sources.list
sudo cat <<EOF> /etc/apt/sources.list
deb http://mirrors.huaweicloud.com/repository/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.huaweicloud.com/repository/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.huaweicloud.com/repository/ubuntu/ focal-backports main restricted universe multiverse
deb http://mirrors.huaweicloud.com/repository/ubuntu/ focal-security main restricted universe multiverse
EOF
sudo apt update 

sudo tee /etc/modules-load.d/k8s.conf <<EOF
    overlay
    br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/k8s.conf <<EOF
    net.bridge.bridge-nf-call-ip6tables = 1
    net.bridge.bridge-nf-call-iptables = 1
    net.ipv4.ip_forward = 1
EOF
sudo sysctl --system
sudo sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward

#================================================
#set swap
#sudo vim /etc/fstab
#================================================
sudo sed -i 's@/swap@#/swap@g' /etc/fstab
sudo swapoff -a
sudo free -h

#================================================
#set containerd
#sudo vim /etc/containerd/config.toml
#================================================
sudo apt update 
sudo apt install -y containerd
sudo mkdir /etc/containerd
sudo containerd config default > /etc/containerd/config.toml

sudo touch /etc/containerd/config.toml
sudo sed -i 's@registry.k8s.io/pause:3.8@registry.aliyuncs.com/google_containers/pause:3.9@g' /etc/containerd/config.toml
sudo sed -i 's@SystemdCgroup = false@SystemdCgroup = true@g' /etc/containerd/config.toml
sudo sed -i 's@\[plugins."io.containerd.grpc.v1.cri".registry.configs\]@\[plugins."io.containerd.grpc.v1.cri".registry.configs\]\n          \[plugins."io.containerd.grpc.v1.cri".registry.configs."'${DockerHub}'".tls\]\n                    insecure_skip_verify = true\n@g'    /etc/containerd/config.toml
sudo sed -i 's@\[plugins."io.containerd.grpc.v1.cri".registry.mirrors\]@\[plugins."io.containerd.grpc.v1.cri".registry.mirrors\]\n          \[plugins."io.containerd.grpc.v1.cri".registry.mirrors."'${DockerHub}'"\]\n                   endpoint = \["http:\/\/'${DockerHub}'"\]\n@g'   /etc/containerd/config.toml

sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo crictl config runtime-endpoint unix:///var/run/containerd/containerd.sock    

#================================================
#set kubernetes
#================================================
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

if  [ -d "/etc/apt/keyrings/" ];then
    echo  "文件夹存在"
    sudo rm -rf /etc/apt/keyrings
fi
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${VERSION::-2}/deb/Release.key | 
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg  

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/'${VERSION::-2}'/deb/ /' | 
sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

sudo curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | 
sudo apt-key add
sudo echo "deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" | 
sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubectl kubeadm kubelet
sudo apt-mark hold kubelet kubeadm kubectl