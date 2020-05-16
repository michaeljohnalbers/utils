locals {
  ami = "ami-003634241a8fcdec0" # Ubuntu 18.04 public image
  joinConfigFile = "joinConfig.yaml"
  key-name = "MichaelKeyPair"
  kubernetes-version = "1.18.2-00"
  name = "kubernetes-sandbox"
  number-workers = 3
  private-cidr = "10.0.1.0/24"
  public-cidr = "10.0.0.0/24"
}
