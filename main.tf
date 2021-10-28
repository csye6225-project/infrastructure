// Create a vpc demo
resource "aws_vpc" "vpc" {
  cidr_block                       = var.vpc_cidr_block
  enable_dns_hostnames             = var.vpc_enable_dns_hostnames
  enable_dns_support               = var.vpc_enable_dns_support
  enable_classiclink_dns_support   = var.vpc_enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block = var.vpc_assign_generated_ipv6_cidr_block
  tags = {
    Name = "assign2-vpc"
  }
}

// Create 3 subnet demo
resource "aws_subnet" "subnet" {

  depends_on = [aws_vpc.vpc]

  for_each = var.subnet_cidr_block_list

  cidr_block              = each.value
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = each.key
  map_public_ip_on_launch = var.subnet_map_public_ip_on_launch
  tags = {
    Name = "assign2-subnet"
  }
}

// Create internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "assign2-internet_gateway"
  }
}

// Create route table and associate it with subnets
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.route_table_cidr_block
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "assign2-route_table"
  }
}
resource "aws_route_table_association" "aws_route_table_association" {
  for_each = aws_subnet.subnet

  subnet_id      = aws_subnet.subnet[each.key].id
  route_table_id = aws_route_table.route_table.id
}

// Create route
resource "aws_route" "route" {
  route_table_id         = aws_route_table.route_table.id
  destination_cidr_block = var.route_destination_cidr_block
  gateway_id             = aws_internet_gateway.internet_gateway.id
  depends_on             = [aws_route_table.route_table]
}

// Create Web Application Security Group
resource "aws_security_group" "webapp_security_group" {
  name        = var.webapp_security_group_name
  description = "Enable TCP access on port 22/80/443/8080"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TCP Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.route_destination_cidr_block]
  }

  ingress {
    description = "TCP Access"
    from_port   = 80
    to_port     = 80
    protocol    = var.wsg_protocol
    cidr_blocks = [var.route_destination_cidr_block]
  }

  ingress {
    description = "TCP Access"
    from_port   = 443
    to_port     = 443
    protocol    = var.wsg_protocol
    cidr_blocks = [var.route_destination_cidr_block]
  }

  ingress {
    description = "TCP Access"
    from_port   = 8080
    to_port     = 8080
    protocol    = var.wsg_protocol
    cidr_blocks = [var.route_destination_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.route_destination_cidr_block]
  }

  tags = {
    Name = "application"
  }
}

// Create Database Security Group
resource "aws_security_group" "db_security_group" {
  name        = "database"
  description = "Enable MySQL access on port 3306"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description     = "TCP Access"
    from_port       = 3306
    to_port         = 3306
    protocol        = var.wsg_protocol
    security_groups = [aws_security_group.webapp_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.route_destination_cidr_block]
  }

  tags = {
    Name = "database"
  }
}

resource "random_string" "random" {
  length           = 2
  special          = false
}

// Create s3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket        = "${random_string.random.result}.dev.pengchengxu.me"
  acl           = "private"
  force_destroy = true


  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

  lifecycle_rule {
    id      = "archive"
    enabled = true
    prefix  = "archive/"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_db_parameter_group" "mysql_8" {
  name   = "rds-pg"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  depends_on = [aws_subnet.subnet]
  name       = "main"
  subnet_ids = [element([for k, v in aws_subnet.subnet : v.id], 1), element([for k, v in aws_subnet.subnet : v.id], 2)]

  tags = {
    Name = "DB subnet group"
  }
}

resource "aws_db_instance" "db_instance" {
  identifier = var.db_instance_name

  allocated_storage = 10
  engine            = "mysql"
  engine_version    = "8.0"
  multi_az          = false

  instance_class         = "db.t3.micro"
  name                   = "csye6225"
  username               = "csye6225"
  password               = "csye6225Fall2021"
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.mysql_8.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot    = true
}

resource "aws_instance" "web" {
  ami                     = "ami-01b060ebdbbcfedb5"
  instance_type           = "t2.micro"
  disable_api_termination = false
  key_name                = "csye6225"

  depends_on           = [aws_db_instance.db_instance]
  iam_instance_profile = aws_iam_instance_profile.iam_profile.name

  vpc_security_group_ids = [aws_security_group.webapp_security_group.id]
  subnet_id              = element([for k, v in aws_subnet.subnet : v.id], 0)

  root_block_device {
    delete_on_termination = true
    volume_size           = "20"
    volume_type           = "gp2"
  }

  user_data = <<EOF
#!/bin/bash
cd /usr/webapp || return
touch application.properties
echo "aws.access_key_id=" >> application.properties
echo "aws.secret_access_key=" >> application.properties
echo "aws.s3.region=us-east-1" >> application.properties
echo "aws.s3.bucket=${aws_s3_bucket.bucket.bucket}" >> application.properties

echo "hibernate.connection.driver_class=com.mysql.cj.jdbc.Driver" >> application.properties
echo "hibernate.connection.url=jdbc:mysql://${aws_db_instance.db_instance.endpoint}/csye6225?serverTimezone=UTC" >> application.properties" >> application.properties
echo "hibernate.connection.username=${aws_db_instance.db_instance.username}" >> application.properties
echo "hibernate.connection.password=${aws_db_instance.db_instance.password}" >> application.properties
echo "hibernate.dialect=org.hibernate.dialect.MySQL8Dialect" >> application.properties
echo "hibernate.show_sql=true" >> application.properties
echo "hibernate.hbm2ddl.auto=update" >> application.properties
EOF

  tags = {
    Name = "ec2 instance"
  }
}

resource "aws_iam_policy" "policy" {
  name        = "WebAppS3"
  path        = "/"
  description = "policy for s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*",
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::aws_s3_bucket.bucket.name",
          "arn:aws:s3:::aws_s3_bucket.bucket.name/*"
        ]
      },
    ]
  })
}

resource "aws_iam_role" "iam_role" {
  name                = "EC2-CSYE6225"
  managed_policy_arns = [aws_iam_policy.policy.arn]
  assume_role_policy  = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
     "Effect": "Allow",        
     "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "iam_profile" {
  name = "iam_profile"
  role = aws_iam_role.iam_role.name
}