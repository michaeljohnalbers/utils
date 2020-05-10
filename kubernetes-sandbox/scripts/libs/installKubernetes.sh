#!/bin/bash

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
