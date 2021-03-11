# ========================= variables =========================
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}

variable "redirector_alias" {
  type = set(string)
}

variable "c2_alias" {
  type = string
}

variable "ip_whitelist" {
  type = list(string)
}

variable "infrastructure_name" {
  type = string
}

# ========================= amazon machine images =========================
resource "aws_instance" "c2" {
  ami                         = "ami-0a43280cfb87ffdba" #https://cloud-images.ubuntu.com/locator/ec2/
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.default_ssh.key_name
  vpc_security_group_ids      = [aws_security_group.covenant_security_group.id]
  subnet_id                   = aws_subnet.default_subnet.id
  associate_public_ip_address = true

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.master_key.private_key_pem
  }

  provisioner "remote-exec" {
    scripts = [
      "./data/scripts/apt_update.sh",
      "./data/scripts/deploy_covenant.sh"
    ]
  }

  tags = {
    Name  = var.infrastructure_name
    alias = var.c2_alias
  }
}

resource "aws_instance" "http_redirector" {
  for_each                    = var.redirector_alias
  ami                         = "ami-0a43280cfb87ffdba" #https://cloud-images.ubuntu.com/locator/ec2/
  instance_type               = "t2.nano"
  key_name                    = aws_key_pair.default_ssh.key_name
  vpc_security_group_ids      = [aws_security_group.http_redirector.id]
  subnet_id                   = aws_subnet.default_subnet.id
  associate_public_ip_address = true

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = tls_private_key.master_key.private_key_pem
  }

  provisioner "remote-exec" {
    scripts = [
      "./data/scripts/apt_update.sh",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      # iptables redirection
      "echo \"127.0.0.1 $(hostname)\" | sudo tee -a /etc/hosts",
      "sudo iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT",
      "sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination ${aws_instance.c2.private_ip}:80",
      "sudo iptables -t nat -A POSTROUTING -j MASQUERADE",
      "sudo iptables -I FORWARD -j ACCEPT",
      "sudo iptables -P FORWARD ACCEPT",
      "sudo sysctl net.ipv4.ip_forward=1",
    ]
  }
  tags = {
    Name  = var.infrastructure_name
    alias = each.key
  }
}

# ========================= providers =========================
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

# ========================= ssh =========================
resource "tls_private_key" "master_key" {
  algorithm = "RSA"
  rsa_bits  = 4096

  provisioner "local-exec" {
    command = "echo \"${tls_private_key.master_key.private_key_pem}\" > ./data/crypto/private.key.pem; chmod 400 ./data/crypto/private.key.pem"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm ./data/crypto/private.key.pem"
  }
}

resource "aws_key_pair" "default_ssh" {
  key_name   = var.infrastructure_name
  public_key = tls_private_key.master_key.public_key_openssh
}

# ========================= network =========================
resource "aws_vpc" "default_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = var.infrastructure_name
  }
}

resource "aws_subnet" "default_subnet" {
  vpc_id     = aws_vpc.default_vpc.id
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = var.infrastructure_name
  }
}

resource "aws_internet_gateway" "default_internet_gateway" {
  vpc_id = aws_vpc.default_vpc.id

  tags = {
    Name = var.infrastructure_name
  }
}

resource "aws_route_table" "default_route_table" {
  vpc_id = aws_vpc.default_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default_internet_gateway.id
  }

  tags = {
    Name = var.infrastructure_name
  }
}

resource "aws_route_table_association" "default_route_table_association" {
  subnet_id      = aws_subnet.default_subnet.id
  route_table_id = aws_route_table.default_route_table.id
}

# ========================= security groups =========================
resource "aws_security_group" "covenant_security_group" {
  name   = "covenant_security_group"
  vpc_id = aws_vpc.default_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 7443
    to_port     = 7443
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.infrastructure_name
  }
}

resource "aws_security_group" "http_redirector" {
  name   = "http_redirector"
  vpc_id = aws_vpc.default_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ip_whitelist
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.infrastructure_name
  }
}

# ========================= outputs =========================
output "outputs" {
  value = [
    "--- infrastructure name ---",
    var.infrastructure_name,
    "--- redirector(s) ---",
    "public ip(s)",
    {
      for instance in aws_instance.http_redirector :
      instance.tags.alias => instance.public_ip
    },
    "private ip(s)",
    {
      for instance in aws_instance.http_redirector :
      instance.tags.alias => instance.private_ip
    },
    "--- c2 ---",
    "public ip",
    {
      (var.c2_alias) = aws_instance.c2.public_ip
    },
    "private ip",
    {
      (var.c2_alias) = aws_instance.c2.private_ip
    },
  ]
}
