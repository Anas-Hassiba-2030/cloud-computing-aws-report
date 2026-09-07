variable "region" {
  description = "AWS region. us-east-1 is the cheapest for most instance types and is what the price table in the report uses."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name tag applied to every resource, so they are easy to find and easy to delete."
  type        = string
  default     = "cloud-project-web"
}

variable "instance_type" {
  description = "EC2 instance type. t4g.micro is Graviton2/Arm and the cheapest usable size (see report section 7)."
  type        = string
  default     = "t4g.micro"
}

variable "my_ip_cidr" {
  description = "Your public IP as a /32 CIDR. SSH is opened to this address only. Get it with: curl -s https://checkip.amazonaws.com"
  type        = string

  validation {
    condition     = var.my_ip_cidr != "0.0.0.0/0"
    error_message = "Refusing to open SSH to the whole internet. Pass your own address as x.x.x.x/32."
  }
}

variable "public_key_path" {
  description = "Path to the PUBLIC half of your SSH key. The private half never leaves your machine."
  type        = string
  default     = "~/.ssh/cloud-project.pub"
}
