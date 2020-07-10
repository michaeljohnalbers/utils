# Kubernetes Sandbox

This Terraform project creates a VPC, subnets, EC2 instances, etc. for a Kubernetes cluster.

## Deploy
Run `terraform apply` to create resources. `terraform destroy` to shut it all down.

## Kubernetes Config
`aws s3 cp s3://albersm.${local.name}.kube-data/kube-config ~/.kube/config`
