# Terraform scripts

## Prerequisites

[Terraform](https://developer.hashicorp.com/terraform/install) should be installed.

## Authorization

These scripts designed to provision only one virtual machine.

Authentication can be done either by setting environment variables

```bash
export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"
export AWS_REGION="us-west-2"
```

or by putting keys to the `$HOME/.aws/credentials` file under profile `scripttv` for example

```toml
[scripttv]
aws_access_key_id = access_key
aws_secret_access_key = secret_key
```

[Here](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration) is documentation for the possible authentication methods.

## Configuration

Configration contained in the `terraform.tfvars` file. Use `terraform.tfvars.example` as an example.

## Usage

First need to run once `make setup`.
Running `make provision` will create a new vm.
Running `make destroy` will destroy it.
