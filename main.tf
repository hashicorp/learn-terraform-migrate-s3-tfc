terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "<BUCKET>"
    dynamodb_table = "terraform-state-lock-dynamo"
    key            = "learn-terraform-s3-migrate-tfc"
    region         = "us-west-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.65.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name      = "HelloWorld"
    workspace = terraform.workspace
  }
}