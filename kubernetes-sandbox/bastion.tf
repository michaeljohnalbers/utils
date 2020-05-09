resource "aws_security_group" "bastion" {
  name_prefix = "${local.name}-bastion"
  vpc_id = aws_vpc.vpc.id
  description = "Allows SSH access to bastion host"
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = -1
    protocol = "icmp"
    to_port = -1
  }
  // Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "bastion" {
  lifecycle {
    create_before_destroy = true
  }
  name_prefix = "${local.name}-bastion"
  associate_public_ip_address = true
  image_id = local.ami
  instance_type = "t2.small"
  key_name = local.key-name
  security_groups = [aws_security_group.bastion.id]
  user_data = file("scripts/bastionInit.sh")
}

resource "aws_autoscaling_group" "bastion" {
  lifecycle {
    create_before_destroy = true
  }
  name_prefix = "${local.name}-bastion"
  max_size = 1
  min_size = 1
  launch_configuration = aws_launch_configuration.bastion.id
  vpc_zone_identifier = [aws_subnet.public.id]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "${local.name}-bastion"
  }
}