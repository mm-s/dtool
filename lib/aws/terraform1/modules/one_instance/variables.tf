
variable "base_name" {
  type = string
}

# Defining Public Key
variable "public_key" {
  type = string
}

variable "private_key_path" {
  type = string
  default = ""
}

# Defining CIDR Block for VPC
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

# Defining CIDR Block for Subnet
variable "subnet1_cidr" {
  default = "10.0.1.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "os" {
  type = string
  default = "debian"
}

