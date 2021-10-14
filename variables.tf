// Provider variables
variable "region" {
  type        = string
  description = "Region"
  default     = "us-east-1"
}

variable "profile" {
  type        = string
  description = "AWS credential"
}

variable "shared_credentials_file" {
  type = string
  description = "AWS credential file"
  default = "~/.aws/credentials"
}



// VPC variables
variable "vpc_cidr_block" {
  type        = string
  description = "CIDR for VPC"
  // default = "10.0.0.0/16"
}

variable "vpc_enable_dns_hostnames" {
  description = "VPC enable dns hostnames setting"
  default     = true
}

variable "vpc_enable_dns_support" {
  description = "VPC enable dns support setting"
  default     = true
}

variable "vpc_enable_classiclink_dns_support" {
  description = "VPC enable classiclink dns support setting"
  default     = true
}

variable "vpc_assign_generated_ipv6_cidr_block" {
  description = "VPC assign_generated_ipv6_cidr_block setting"
  default     = false
}



// Subnet variables
variable "subnet_cidr_block_list" {
  description = "CIDR for Subnets"
  // default = "10.0.1.0/24"
}

variable "subnet_map_public_ip_on_launch" {
  description = "Subnet map public ip on launch setting"
  default     = true
}



// Route table variables
variable "route_table_cidr_block" {
  type        = string
  description = "CIDR for Route_Table"
  // default = "10.1.0.0/24"
}



variable "route_destination_cidr_block" {
  type        = string
  description = "Destination CIDR for Route"
  // default = "0.0.0.0/0"
}