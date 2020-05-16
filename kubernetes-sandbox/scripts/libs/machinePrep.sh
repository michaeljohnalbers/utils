#!/bin/bash

apt-get update -y
apt-get upgrade -y
apt-get install -y awscli jq

hostname=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
hostnamectl set-hostname $hostname