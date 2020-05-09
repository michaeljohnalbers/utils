locals {
  ami = "ami-003634241a8fcdec0" # Ubuntu 18.04 public image
  key-name = "MichaelKeyPair"
  kubernetes-version = "1.18.2-00"
  name = "kubernetes-sandbox"
  private-cidr = "10.0.1.0/24"
  public-cidr = "10.0.0.0/24"
}
