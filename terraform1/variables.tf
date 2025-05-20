
variable "base_name" {
  type = string
}

# Defining Public Key
variable "public_key" {
  type = string
}

# Defining Private Key
variable "private_key_path" {
  type = string
  default = ""
}

# Definign Key Name for connection
variable "key_name" {
  default     = "tests"
  description = "Name of AWS key pair"
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

variable "region" {
  type = string
  default = "us-east-2"
}