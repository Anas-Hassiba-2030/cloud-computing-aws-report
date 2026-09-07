##############################################################################
# Cloud Computing project - Amazon EC2 virtual machine, defined as code.
#
# This is path 3 of the three VM-creation paths described in report.html
# (section 5). It builds exactly the same instance as the console walkthrough
# (5.1) and the CLI script (5.2), so the three can be compared side by side.
#
#   terraform init
#   terraform plan  -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
#   terraform apply -var="my_ip_cidr=$(curl -s https://checkip.amazonaws.com)/32"
#   terraform destroy          # <- do this when the demo is over, it stops the bill
#
# Everything below is free-tier friendly EXCEPT the instance itself if you
# change instance_type. Check the price table in report.html section 7.
##############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# 1. The image (AMI). Never hard-code an AMI id: they are region-specific and
#    they change every time Amazon patches the OS. Look the latest one up.
# ---------------------------------------------------------------------------
data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }
}

# ---------------------------------------------------------------------------
# 2. The network. Default VPC + its default subnets keeps this teaching example
#    short; a production build would declare its own VPC, public/private
#    subnets and NAT gateway (see the block diagram, Figure 3).
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------
# 3. The firewall. SSH is scoped to ONE address - yours. Opening 22 to
#    0.0.0.0/0 is the single most common mistake in this exercise; automated
#    scanners find a new public SSH port in minutes.
# ---------------------------------------------------------------------------
resource "aws_security_group" "web" {
  name        = "${var.name}-sg"
  description = "HTTP from anywhere, SSH from one address only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from my address only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP from the internet - this is a public web server"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound - needed for dnf updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-sg" }
}

# ---------------------------------------------------------------------------
# 4. The key pair. Terraform uploads the PUBLIC half of a key you generated
#    locally. AWS never sees the private half, which is the point.
#
#      ssh-keygen -t ed25519 -f ~/.ssh/cloud-project -C "cloud-project"
#      chmod 400 ~/.ssh/cloud-project
# ---------------------------------------------------------------------------
resource "aws_key_pair" "this" {
  key_name   = "${var.name}-key"
  # pathexpand, because Terraform's file() does not expand a leading "~".
  public_key = file(pathexpand(var.public_key_path))
}

# ---------------------------------------------------------------------------
# 5. The instance itself.
# ---------------------------------------------------------------------------
resource "aws_instance" "vm" {
  ami                         = data.aws_ami.al2023_arm.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/../scripts/user-data.sh")

  # gp3 is cheaper and faster than gp2 at the same size. Delete on termination
  # so a destroyed demo does not leave a billed orphan volume behind.
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # IMDSv2 required. Without this, a server-side request forgery bug in the
  # app running on the VM can be used to read the instance's IAM credentials.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = var.name
    Project = "cloud-computing-report"
    Owner   = "student"
  }
}
