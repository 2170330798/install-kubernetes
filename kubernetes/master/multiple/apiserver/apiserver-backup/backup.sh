#!/bin/bash
################################BACKUP###################################
#set variables
#keppalived:
export ROUTER_ID="VRRP-02"
export APISERVER_VIP="192.168.10.254/24"
export AUTH_PASS="nullmax@123"
export STATE="BACKUP"
export INTERFACE="ens33"
export ROUTER_ID="50"
export PRIORITY="100"
#haproxy:
export APISERVER_DEST_PORT="6443"
export APISERVER_SRC_PORT="6443"
export APISERVER_SUMS="3"
export APISERVER_IDS=("k8-master-01" "k8-master-02" "k8-master-03")
export APISERVER_ADDRESSES=("192.168.10.160" "192.168.10.161" "192.168.10.162")
#apiserver:
export HOST="192.168.10.164"
export MASK="24"
export GetWay="192.168.10.2"
export DnsServers="8.8.8.8, 114.114.114.114"

if  [ ! -f  "/etc/netplan/50-cloud-init.yaml" ];then
  sudo touch /etc/netplan/50-cloud-init.yaml
fi
sudo cat <<EOF> /etc/netplan/50-cloud-init.yaml
   network:
      version: 2
      renderer: networkd
      ethernets:
        ens33:
          dhcp4: no
          addresses: 
            - ${HOST}/${MASK}
          routes:
            - to: default
              via: ${GetWay}
          nameservers:
            addresses: [${DnsServers}]
EOF
sudo netplan apply

#install
sudo apt update 
sudo apt install -y haproxy keepalived

if [ ! -f "/etc/keepalived/keepalived.conf"]; then
    sudo touch /etc/keepalived/keepalived.conf
fi

sudo cat <<EOF> /etc/keepalived/keepalived.conf
! /etc/keepalived/keepalived.conf
! Configuration File for keepalived
global_defs {
        router_id ${ROUTER_ID}
        script_user root
        enable_script_security
}
vrrp_script check_apiserver {
   script "/etc/keepalived/check_apiserver.sh"
   interval 3
   weight -2
   fall 10
   rise 2
}

vrrp_instance VI_1 {
      state ${STATE}
      interface ${INTERFACE}
      virtual_router_id ${ROUTER_ID}
      priority ${PRIORITY}
      authentication {
          auth_type PASS
          auth_pass ${AUTH_PASS}
      }
      virtual_ipaddress {
          ${APISERVER_VIP}
      }
      track_script {
          check_apiserver
      }
}
EOF


if [ ! -f "/etc/keepalived/check_apiserver.sh"]; then
    sudo touch /etc/keepalived/check_apiserver.sh
fi
sudo cat <<EOF> /etc/keepalived/check_apiserver.sh
#!/bin/bash
errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

curl -sfk --max-time 2 https://localhost:${APISERVER_DEST_PORT}/healthz -o /dev/null || errorExit "Error GET https://localhost:${APISERVER_DEST_PORT}/healthz"
EOF
sudo chmod +x /etc/keepalived/check_apiserver.sh


if [ ! -f "/etc/haproxy/haproxy.cfg"]; then
    sudo touch /etc/haproxy/haproxy.cfg
fi
sudo cat <<EOF> /etc/haproxy/haproxy.cfg
    # /etc/haproxy/haproxy.cfg
    #---------------------------------------------------------------------
    # Global settings
    #---------------------------------------------------------------------
    global
        log stdout format raw local0
        daemon

    #---------------------------------------------------------------------
    # common defaults that all the 'listen' and 'backend' sections will
    # use if not designated in their block
    #---------------------------------------------------------------------
    defaults
        mode                    http
        log                     global
        option                  httplog
        option                  dontlognull
        option http-server-close
        option forwardfor       except 127.0.0.0/8
        option                  redispatch
        retries                 1
        timeout http-request    10s
        timeout queue           20s
        timeout connect         5s
        timeout client          35s
        timeout server          35s
        timeout http-keep-alive 10s
        timeout check           10s

    #---------------------------------------------------------------------
    # apiserver frontend which proxys to the control plane nodes
    #---------------------------------------------------------------------
    frontend apiserver
        bind *:${APISERVER_DEST_PORT}
        mode tcp
        option tcplog
        default_backend apiserverbackend

    #---------------------------------------------------------------------
    # round robin balancing for apiserver
    #---------------------------------------------------------------------
    backend apiserverbackend
        option httpchk

        http-check connect ssl
        http-check send meth GET uri /healthz
        http-check expect status 200

        mode tcp
        balance     roundrobin
    
        #add apiserver
        #server HOST1_ID HOST_ADDRESS:APISERVER_SRC_PORT check verify none
EOF

for ((i=0;i<${APISERVER_SUMS};i++))
do           
    HOST_ID=${APISERVER_IDS[i]}
    HOST_ADDRESS=${APISERVER_ADDRESSES[i]}
    sudo sed -i '$ a \        server '${HOST_ID}' '${HOST_ADDRESS}':'${APISERVER_SRC_PORT}' check verify none' /etc/haproxy/haproxy.cfg 
done    

sudo systemctl enable haproxy --now
sudo systemctl enable keepalived --now

