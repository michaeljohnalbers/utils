#!/bin/bash

set -ex

# This runs as root. View output at /var/log/cloud-init-output.log.

${machinePrep}

${installDocker}

${installKubernetes}

# Wait for join command file to show up in S3.
while [[ -z $(aws s3api head-object --bucket ${s3BucketName} --key ${joinConfigFile} || true) ]] ; do
  echo "Join cluster file, ${joinConfigFile}, not in S3 yet."
  sleep 1
done

aws s3 cp s3://${s3BucketName}/${joinConfigFile} /

kubeadm join --config /${joinConfigFile}
