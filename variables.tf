// Provider variables
variable "region" {
  type        = string
  description = "Region"
  default     = "us-east-1"
}

variable "aws_access_key" {
  type        = string
  description = "Access Key"
}

variable "aws_secret_key" {
  type        = string
  description = "Secret Key"
}


variable "ami" {
  type        = string
  description = "AMI"
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

variable "webapp_security_group_name" {
  type        = string
  description = "name for webapp_security_group_name"
  default     = "application"
}

variable "wsg_protocol" {
  type    = string
  default = "tcp"
}

variable "db_security_group_name" {
  type        = string
  description = "name for db security group"
  default     = "database"
}

variable "db_instance_name" {
  type        = string
  description = "name for db instance"
  default     = "csye6225"
}

variable "db_instance_replica_name" {
  type        = string
  description = "name for db instance read replica"
  default     = "csye6225-replica"
}

variable "db_instance_engine" {
  type        = string
  description = "engine for db instance"
  default     = "mysql"
}

variable "db_instance_class" {
  type        = string
  description = "class for db instance"
  default     = "db.t3.micro"
}

variable "db_instance_username" {
  type        = string
  description = "username for db instance"
  default     = "csye6225"
}

variable "db_instance_password" {
  type        = string
  description = "password for db instance"
  default     = "csye6225Fall2021"
}

variable "aws_instance_type" {
  type        = string
  description = "instance type"
  default     = "t2.micro"
}

variable "hosted_zone_name" {
  type    = string
  default = "prod.pengchengxu.me"
}


variable "key_name" {
  type    = string
  default = "csye6225"
}

variable "s3_bucket_name" {
  type    = string
  default = "xpc.prod.pengchengxu.me"
}

