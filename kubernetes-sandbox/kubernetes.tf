resource "aws_s3_bucket" "kube-data" {
  bucket = "albersm.${local.name}.kube-data"
  acl = "private"
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
    s3BucketName = aws_s3_bucket.kube-data.bucket,
    kubernetesVersion = local.kubernetes-version,
    publicIp = aws_eip.master-node.public_ip})
  subnet_id = aws_subnet.public.id
  security_groups = [aws_security_group.kube-master.id]
  key_name = local.key-name
  iam_instance_profile = aws_iam_instance_profile.allow-all.id

  tags = {
    Name = "kubernetes-master"
  }
}

resource "aws_eip_association" "master-node" {
  instance_id = aws_instance.master-node.id
  allocation_id = aws_eip.master-node.id
}

# TODO: security group for workers
# TODO: worker nodes
