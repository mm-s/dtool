
provider "aws" {
  # region  = "us-east-1"
  region  = var.region
  profile = "scripttv"
  default_tags {
    tags = {
      Environment = "AutoBuild"
      DeployedBy  = "Terraform"
    }
  }
}

#################### Providers for all regions ####################
provider "aws" {
  profile = "scripttv"
  alias      = "ap-northeast-1"
  region     = "ap-northeast-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "ap-northeast-2"
  region     = "ap-northeast-2"
}
provider "aws" {
  profile = "scripttv"
  alias      = "ap-northeast-3"
  region     = "ap-northeast-3"
}
provider "aws" {
  profile = "scripttv"
  alias      = "ap-south-1"
  region     = "ap-south-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "ap-southeast-1"
  region     = "ap-southeast-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "ap-southeast-2"
  region     = "ap-southeast-2"
}
provider "aws" {
  profile = "scripttv"
  alias      = "ca-central-1"
  region     = "ca-central-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "eu-central-1"
  region     = "eu-central-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "eu-north-1"
  region     = "eu-north-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "eu-west-1"
  region     = "eu-west-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "eu-west-2"
  region     = "eu-west-2"
}
provider "aws" {
  profile = "scripttv"
  alias      = "eu-west-3"
  region     = "eu-west-3"
}
provider "aws" {
  profile = "scripttv"
  alias      = "sa-east-1"
  region     = "sa-east-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "us-east-1"
  region     = "us-east-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "us-east-2"
  region     = "us-east-2"
}
provider "aws" {
  profile = "scripttv"
  alias      = "us-west-1"
  region     = "us-west-1"
}
provider "aws" {
  profile = "scripttv"
  alias      = "us-west-2"
  region     = "us-west-2"
}

