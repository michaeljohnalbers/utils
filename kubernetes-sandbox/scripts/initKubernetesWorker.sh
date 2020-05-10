#!/bin/bash

set -ex

# This runs as root. View output at /var/log/cloud-init-output.log.

${aptUpgrade}

${installDocker}

${installKubernetes}

# Wait for join command file to show up in S3.
while [[ -z $(aws s3api head-object --bucket ${s3BucketName} --key ${joinClusterFile} || true) ]] ; do
  echo "Join cluster file, ${joinClusterFile}, not in S3 yet."
  sleep 1
done

aws s3 cp s3://${s3BucketName}/${joinClusterFile} /
chmod 755 /${joinClusterFile}
/${joinClusterFile}
