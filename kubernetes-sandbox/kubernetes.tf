resource "aws_s3_bucket" "kube-data" {
  bucket = "albersm.${local.name}.kube-data"
  acl = "private"
  provisioner "local-exec" {
    when = destroy
    command = "aws s3 rm --recursive s3://${self.bucket}"
  }
}

resource "aws_security_group" "kube-master" {
  name = "${local.name}-kube-master"
  description = "For kubernetes master node"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    description = "ssh"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    from_port = 6443
    protocol = "tcp"
    to_port = 6443
    description = "apiserver"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    cidr_blocks = [local.public-cidr, local.private-cidr]
    from_port = 2379
    protocol = "tcp"
    to_port = 2380
    description = "etcd"
  }
  ingress {
    cidr_blocks = [local.public-cidr, local.private-cidr]
    from_port = 10250
    protocol = "tcp"
    to_port = 10252
    description = "kubelet, kube-scheduler, kube-controller"
  }

  // Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "allow-all" {
  name = "${local.name}-allow-all"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource "aws_iam_role_policy" "allow-all" {
  name = "${local.name}-allow-all"
  role = aws_iam_role.allow-all.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_instance_profile" "allow-all" {
  name = "${local.name}-allow-all"
  role = aws_iam_role.allow-all.name
}

resource "aws_eip" "master-node" {
  depends_on = [aws_internet_gateway.internet-gateway]  // See resource documentation.
  vpc = true
  tags = {
    Name = "${local.name}-master-node"
  }
}

resource "aws_instance" "master-node" {
  // Make sure this doesn't start until the full VPC is up
  depends_on = [aws_route_table.private, aws_nat_gateway.gateway]

  ami = local.ami
  instance_type = "t3a.large"
  user_data = templatefile("scripts/initKubernetesMaster.sh", {
    machinePrep = file("scripts/libs/machinePrep.sh"),
    installDocker = file("scripts/libs/installDocker.sh"),
    installKubernetes = templatefile("scripts/libs/installKubernetes.sh", {
      kubernetesVersion = local.kubernetes-version}),
    clusterName = local.name,
    joinConfigFile = local.joinConfigFile,
    publicIp = aws_eip.master-node.public_ip
    s3BucketName = aws_s3_bucket.kube-data.bucket
  })
  subnet_id = aws_subnet.public.id
  security_groups = [aws_security_group.kube-master.id]
  key_name = local.key-name
  iam_instance_profile = aws_iam_instance_profile.allow-all.id

  tags = {
    Name = "kubernetes-master"
    "kubernetes.io/cluster/${local.name}" = "owned"
  }
}

resource "aws_eip_association" "master-node" {
  instance_id = aws_instance.master-node.id
  allocation_id = aws_eip.master-node.id
}

resource "aws_security_group" "kube-worker" {
  name = "${local.name}-kube-worker"
  description = "For kubernetes worker nodes"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    description = "ssh"
    security_groups = [aws_security_group.bastion.id]
  }
  ingress {
    cidr_blocks = [local.public-cidr, local.private-cidr]
    from_port = 10250
    protocol = "tcp"
    to_port = 10250
    description = "kubelet"
  }
  ingress {
    cidr_blocks = [local.public-cidr, local.private-cidr]
    from_port = 30000
    protocol = "tcp"
    to_port = 32767
    description = "NodePorts"
  }

  // Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "worker-node" {
  count = local.number-workers
  depends_on = [aws_instance.master-node]

  ami = local.ami
  instance_type = "t3a.large"
  user_data = templatefile("scripts/initKubernetesWorker.sh", {
    machinePrep = file("scripts/libs/machinePrep.sh"),
    installDocker = file("scripts/libs/installDocker.sh"),
    installKubernetes = templatefile("scripts/libs/installKubernetes.sh", {
      kubernetesVersion = local.kubernetes-version}),
    s3BucketName = aws_s3_bucket.kube-data.bucket,
    joinConfigFile = local.joinConfigFile
  })
  subnet_id = aws_subnet.private.id
  security_groups = [aws_security_group.kube-worker.id]
  key_name = local.key-name
  iam_instance_profile = aws_iam_instance_profile.allow-all.id

  tags = {
    Name = "kubernetes-worker"
    "kubernetes.io/cluster/${local.name}" = "owned"
  }
}
