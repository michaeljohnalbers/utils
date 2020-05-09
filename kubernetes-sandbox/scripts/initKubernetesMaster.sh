#!/bin/bash

set -ex

# This runs as root. View output at /var/log/cloud-init-output.log.

# See https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

apt-get update -y
apt-get upgrade -y
apt-get install -y awscli

#
# Set up IP tables
#
modprobe br_netfilter
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

#
# Install Docker
#
apt-get install docker.io -y

cat <<EOF | tee -a /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl enable docker.service
systemctl daemon-reload
systemctl restart docker
usermod -a -G docker ubuntu

#
# Install Kubeadm
#
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet=${kubernetesVersion} kubeadm=${kubernetesVersion} kubectl=${kubernetesVersion}
apt-mark hold kubelet kubeadm kubectl

#
# Create the cluster
#
outputFile=/kubeadm-output.txt
# https://github.com/kubernetes/kubeadm/issues/1390
kubeadm init --pod-network-cidr=192.168.0.0/16  --apiserver-cert-extra-sans=${publicIp} | tee -a $outputFile

sudo -u ubuntu bash << "EOF"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
EOF

KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml

#
# Send join command and kubeconfig to s3
#
joinCommandFile=/joinCommand.sh
echo '#!/bin/bash' > $joinCommandFile
grep -A1 '^\s*kubeadm join' $outputFile >> $joinCommandFile
aws s3 cp $joinCommandFile s3://${s3BucketName}
privateIp=$(hostname -i | awk '{print $1}')
sed -e "s~https://$privateIp~https://${publicIp}~" /etc/kubernetes/admin.conf > /publicKubeConfig.conf
aws s3 cp /publicKubeConfig.conf s3://${s3BucketName}/kube-config
