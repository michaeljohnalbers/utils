#!/bin/bash

set -ex

# This runs as root. View output at /var/log/cloud-init-output.log.

# See https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

${machinePrep}

${installDocker}

${installKubernetes}

#
# Create the cluster
#
kubeadmConfigFile=/kubeadmConfig.yaml
cat << EOF > $kubeadmConfigFile
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "aws"
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
networking:
  podSubnet: "192.168.0.0/16"  # For calico
apiServer:
  certSANs:
    - "${publicIp}"
  extraArgs:
    cloud-provider: "aws"
clusterName: "${clusterName}"
controllerManager:
  extraArgs:
    cloud-provider: "aws"
EOF

outputFile=/kubeadm-output.txt
# https://github.com/kubernetes/kubeadm/issues/1390
kubeadm init --config $kubeadmConfigFile | tee -a $outputFile

sudo -u ubuntu bash << "EOF"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
EOF

export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml

#
# Send join config and kubeconfig to s3
#
privateIp=$(hostname -i | awk '{print $1}')
sed -e "s~https://$privateIp~https://${publicIp}~" /etc/kubernetes/admin.conf > /publicKubeConfig.conf
aws s3 cp /publicKubeConfig.conf s3://${s3BucketName}/kube-config

# This is really ugly, but I can't find a better way to join the cluster
# and provide the cloud provider. See
# https://computingforgeeks.com/join-new-kubernetes-worker-node-to-existing-cluster/
joinConfigFile="${joinConfigFile}"
token=$(kubeadm token list --skip-headers | sed 1d | awk '{print $1}')
certHash=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')
cat <<EOF > /$joinConfigFile
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
discovery:
  bootstrapToken:
    token: $token
    apiServerEndpoint: $${privateIp}:6443
    caCertHashes:
      - "sha256:$certHash"
nodeRegistration:
  kubeletExtraArgs:
    cloud-provider: "aws"
EOF
aws s3 cp /$joinConfigFile s3://${s3BucketName}/$joinConfigFile

# Create basic storage class
storageClassFile=/storageClass.yaml
cat <<EOF > $storageClassFile
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  labels:
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
  - debug
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f $storageClassFile
