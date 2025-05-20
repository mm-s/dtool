
locals {
  image_name  = var.os == "debian" ? "debian-12-*" : "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
  owners      = var.os == "debian" ? "040783991365" : "099720109477" # Canonical
  user        = var.os == "debian" ? "admin" : "ubuntu"
  private_key = var.private_key_path != "" ? file(var.private_key_path) : null
}
resource "random_string" "key_postfix" {
  length  = 8
  special = false
  keepers = {
    base_name = var.base_name
  }
}

data "aws_availability_zones" "available" {}

locals {
  ssh_key_name = "${var.base_name}-${random_string.key_postfix.result}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)
}


#Creating VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.base_name}-MainVPC"
  }
}

# Creating 1st subnet 
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet1_cidr
  map_public_ip_on_launch = true
  availability_zone       = local.azs[0]
  # availability_zone       = "us-east-1a"
  # availability_zone_id                           = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = {
    Name = "${var.base_name}-first-subnet"
  }
}

# Creating Internet Gateway 
resource "aws_internet_gateway" "igateway" {
  vpc_id = aws_vpc.main.id
}

#Creating Route Table
resource "aws_route_table" "route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igateway.id
  }

  tags = {
    Name = "Route to internet"
  }
}

resource "aws_route_table_association" "rt1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route.id
}

# Creating Security Group for EC2 instances
resource "aws_security_group" "sg" {

  vpc_id = aws_vpc.main.id

  # Inbound Rules
  # Internet access from anywhere
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound Rules
  # Internet access to anywhere
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creating key pair
resource "aws_key_pair" "sshkey" {
  key_name   = local.ssh_key_name
  public_key = var.public_key
}

data "aws_ami" "image" {
  most_recent = true
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "name"
    values = [local.image_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  #   owners = [local.owners]
}


resource "aws_instance" "main" {
  ami                    = data.aws_ami.image.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  private_dns_name_options {
    enable_resource_name_dns_a_record = true
  }

  #   root_block_device {
  #     volume_size = 16
  #   }

  tags = {
    Name = "${var.base_name}-main"
  }
  key_name = local.ssh_key_name

  provisioner "file" {
    # source      = "./scripts"
    content = templatefile("./scripts/ubuntu_provision.sh", {
      user = local.user
    })
    destination = "/tmp/ubuntu_provision.sh"

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = local.user
      private_key = local.private_key
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo cloud-init status --wait",
      "cd /tmp/",
      "sudo chmod +x /tmp/ubuntu_provision.sh",
      "sudo -E /tmp/ubuntu_provision.sh",
    ]
    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = local.user
      private_key = local.private_key
    }
  }

  #   lifecycle {
  #     ignore_changes = all
  #   }
}

output "info" {
  #   value = aws_instance.main.public_ip
  value = aws_instance.main
}


# output "images" {
#   value = data.aws_ami.image
# }
