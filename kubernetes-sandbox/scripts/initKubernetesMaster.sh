#!/bin/bash

set -ex

# This runs as root. View output at /var/log/cloud-init-output.log.

# See https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

${aptUpgrade}

${installDocker}

${installKubernetes}

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
joinCommandFile=/${joinClusterFile}
echo '#!/bin/bash' > $joinCommandFile
grep -A1 '^\s*kubeadm join' $outputFile >> $joinCommandFile
aws s3 cp $joinCommandFile s3://${s3BucketName}
privateIp=$(hostname -i | awk '{print $1}')
sed -e "s~https://$privateIp~https://${publicIp}~" /etc/kubernetes/admin.conf > /publicKubeConfig.conf
aws s3 cp /publicKubeConfig.conf s3://${s3BucketName}/kube-config
