data "aws_iam_role" "cdes_role" {
  name = "CodeDeployEC2ServiceRole"
}

data "aws_iam_role" "cds_role" {
  name = "CodeDeployServiceRole"
}

data "aws_route53_zone" "selected" {
  name = var.hosted_zone_name
}

data "aws_iam_policy_document" "sns_policy_document" {
  version = "2012-10-17"
  statement {
    sid = "ec2publish"
    actions = [
      "sns:Publish"
    ]
    resources = [
      aws_sns_topic.verification_notice.arn
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy_document" "dynamodb_policy_document" {
  version = "2012-10-17"
  statement {
    sid = "ListAndDescribe"
    actions = [
      "dynamodb:List*",
      "dynamodb:DescribeReservedCapacity*",
      "dynamodb:DescribeLimits",
      "dynamodb:DescribeTimeToLive"
    ]
    resources = [
      "*"
    ]
    effect = "Allow"
  }
  statement {
    sid = "SpecificTable"
    actions = [
      "dynamodb:BatchGet*",
      "dynamodb:DescribeStream",
      "dynamodb:DescribeTable",
      "dynamodb:Get*",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchWrite*",
      "dynamodb:CreateTable",
      "dynamodb:Delete*",
      "dynamodb:Update*",
      "dynamodb:PutItem"
    ]
    resources = [
      "arn:aws:dynamodb:*:*:table/verification"
    ]
    effect = "Allow"
  }
}

data "aws_iam_policy" "lambda_basic" {
  name = "AWSLambdaBasicExecutionRole"
}

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
  depends_on = [aws_subnet.subnet]
  for_each   = aws_subnet.subnet

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

// Create s3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket        = var.s3_bucket_name
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

// resource "aws_db_subnet_group" "replica_subnet_group" {
//   depends_on = [aws_subnet.subnet]
//   name       = "replica"
//   subnet_ids = [element([for k, v in aws_subnet.subnet : v.id], 0), element([for k, v in aws_subnet.subnet : v.id], 2)]

//   tags = {
//     Name = "DB replica subnet group"
//   }
// }

resource "aws_db_instance" "db_instance" {
  identifier = var.db_instance_name

  allocated_storage = 10
  engine            = var.db_instance_engine
  engine_version    = "8.0"
  multi_az          = false

  instance_class          = var.db_instance_class
  name                    = "csye6225"
  username                = var.db_instance_username
  password                = var.db_instance_password
  publicly_accessible     = false
  parameter_group_name    = aws_db_parameter_group.mysql_8.name
  vpc_security_group_ids  = [aws_security_group.db_security_group.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot     = true
  backup_retention_period = 1
}

resource "aws_db_instance" "db_instance_replica" {
  identifier = var.db_instance_replica_name

  replicate_source_db = aws_db_instance.db_instance.arn

  multi_az = false

  instance_class         = var.db_instance_class
  publicly_accessible    = false
  parameter_group_name   = aws_db_parameter_group.mysql_8.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot    = true
}

resource "aws_iam_policy" "policy" {
  name        = "WebAppS3"
  description = "policy for s3"

  policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Action" : ["s3:DeleteObject", "s3:PutObject", "s3:GetObject"]
        "Effect" : "Allow"
        "Resource" : ["arn:aws:s3:::${aws_s3_bucket.bucket.bucket}", "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"]
      }
    ]
  })
}

// resource "aws_iam_role" "iam_role" {
//   name                = "EC2-CSYE6225"
//   managed_policy_arns = [aws_iam_policy.policy.arn]
//   assume_role_policy  = <<EOF
// {
//   "Version": "2012-10-17",
//   "Statement": [
//     {
//       "Action": "sts:AssumeRole",
//       "Principal": {
//         "Service": "ec2.amazonaws.com"
//       },
//      "Effect": "Allow",        
//      "Sid": ""
//     }
//   ]
// }
// EOF
// }

resource "aws_iam_policy" "sns_policy" {
  name        = "sns-policy"
  policy      = data.aws_iam_policy_document.sns_policy_document.json
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "dynamodb-policy"
  policy      = data.aws_iam_policy_document.dynamodb_policy_document.json
}

resource "aws_iam_policy_attachment" "web-app-s3-attach" {
  name       = "gh-upload-to-s3-attachment"
  roles      = [data.aws_iam_role.cdes_role.name]
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_policy_attachment" "dynamodb-ec2-attach" {
  name       = "ec2-use-dynamodb-attachment"
  roles      = [data.aws_iam_role.cdes_role.name]
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

resource "aws_iam_policy_attachment" "sns-ec2-attach" {
  name       = "ec2-use-sns-attachment"
  roles      = [data.aws_iam_role.cdes_role.name]
  policy_arn = aws_iam_policy.sns_policy.arn
}

resource "aws_iam_instance_profile" "iam_role_profile" {
  name = "iam_profile"
  role = data.aws_iam_role.cdes_role.name
}

resource "aws_codedeploy_app" "webapp" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}


resource "aws_codedeploy_deployment_group" "example" {
  app_name               = aws_codedeploy_app.webapp.name
  deployment_group_name  = "csye6225-webapp-deployment"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  service_role_arn       = data.aws_iam_role.cds_role.arn
  autoscaling_groups     = [aws_autoscaling_group.autoscaling_group.name]

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "ec2 instance"
    }
  }

  deployment_style {
    deployment_type = "IN_PLACE"
  }
}

resource "aws_route53_record" "route53_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.hosted_zone_name
  type    = "A"
  // ttl     = "300"
  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_launch_configuration" "launch_config" {
  name                        = "asg_launch_config"
  image_id                    = var.ami
  instance_type               = var.aws_instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  security_groups             = [aws_security_group.webapp_security_group.id]
  iam_instance_profile        = aws_iam_instance_profile.iam_role_profile.name

  user_data = <<EOF
#!/bin/bash
cd /home/ubuntu/app || return
touch application.properties
echo "aws.access_key_id=${var.aws_access_key}" >> application.properties
echo "aws.secret_access_key=${var.aws_secret_key}" >> application.properties
echo "aws.region=${var.region}" >> application.properties
echo "aws.s3.bucket=${aws_s3_bucket.bucket.bucket}" >> application.properties
echo "aws.sns.arn=${aws_sns_topic.verification_notice.arn}" >> application.properties

echo "spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver" >> application.properties
echo "spring.datasource.jdbc-url=jdbc:mysql://${aws_db_instance.db_instance.endpoint}/${aws_db_instance.db_instance.name}?serverTimezone=UTC" >> application.properties
echo "spring.datasource.username=${aws_db_instance.db_instance.username}" >> application.properties
echo "spring.datasource.password=${aws_db_instance.db_instance.password}" >> application.properties

echo "spring.seconddatasource.driverClassName=com.mysql.cj.jdbc.Driver" >> application.properties
echo "spring.seconddatasource.jdbc-url=jdbc:mysql://${aws_db_instance.db_instance_replica.endpoint}/${aws_db_instance.db_instance.name}?serverTimezone=UTC" >> application.properties
echo "spring.seconddatasource.username=${aws_db_instance.db_instance.username}" >> application.properties
echo "spring.seconddatasource.password=${aws_db_instance.db_instance.password}" >> application.properties

echo "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect" >> application.properties
echo "spring.jpa.database=mysql" >> application.properties
echo "spring.jpa.show-sql=true" >> application.properties
echo "spring.jpa.hibernate.ddl-auto=update" >> application.properties

echo "logging.file.name=csye6225.log" >> application.properties
echo "logging.level.root=warn" >> application.properties
echo "logging.level.org.springframework.web=debug" >> application.properties
echo "logging.level.org.hibernate=error" >> application.properties 
  EOF

}


resource "aws_autoscaling_group" "autoscaling_group" {
  name                 = "ec2_autoscaling"
  default_cooldown     = 60
  launch_configuration = aws_launch_configuration.launch_config.name
  min_size             = 3
  max_size             = 5
  desired_capacity     = 3
  vpc_zone_identifier  = [for k, v in aws_subnet.subnet : v.id]

  tag {
    key                 = "Name"
    value               = "ec2 instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "over_five" {
  alarm_name          = "over_five"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "Monitors ec2 cpu utilization over 5%"
  alarm_actions     = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale_down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 10
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "below_three" {
  alarm_name          = "below_three"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }

  alarm_description = "Monitors ec2 cpu utilization below 3%"
  alarm_actions     = [aws_autoscaling_policy.scale_down.arn]
}

resource "aws_security_group" "lb_security_group" {
  name        = "lb_security_group"
  description = "Load Balancer Security Groups"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TCP Access"
    from_port        = 80
    to_port          = 80
    protocol         = var.wsg_protocol
    ipv6_cidr_blocks = ["::/0"]
    cidr_blocks      = [var.route_destination_cidr_block]
  }

  egress {
    from_port       = 8080
    to_port         = 8080
    protocol        = var.wsg_protocol
    security_groups = [aws_security_group.webapp_security_group.id]
  }

  tags = {
    Name = "application"
  }
}

resource "aws_lb" "load_balancer" {
  name               = "applb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_security_group.id]
  subnets            = [for k, v in aws_subnet.subnet : v.id]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_lb_target_group" "target_group" {
  name     = "lb-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
  health_check {
    path                = "/123"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "200"
  }
}

resource "aws_autoscaling_attachment" "tg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.id
  alb_target_group_arn   = aws_lb_target_group.target_group.arn
}

resource "aws_dynamodb_table" "dynamodb_table" {
  name     = "verification"
  hash_key = "email"
  read_capacity = 5
  write_capacity = 5

  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "email"
    type = "S"
  }

  ttl {
    attribute_name = "expireTime"
    enabled        = true
  }
}

resource "aws_sns_topic" "verification_notice" {
  name = "verification-notice"
}

resource "aws_iam_policy_attachment" "dynamodb-lambda-attach" {
  name       = "lambda-use-dynamodb-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

resource "aws_iam_policy_attachment" "lambda-basic-attach" {
  name       = "lambda-basic-attachment"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = data.aws_iam_policy.lambda_basic.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_iam_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_lambda_function" "lambda" {
  function_name = "send_email"
  role          = aws_iam_role.lambda_role.arn
  filename      = "untitled-1.0-SNAPSHOT.jar"
  handler       = "LambdaFunctionHandler"
  runtime       = "java8"
  memory_size   = 3072
}

resource "aws_lambda_permission" "sns_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.verification_notice.arn
}

resource "aws_sns_topic_subscription" "sns_to_lambda" {
  depends_on = [aws_lambda_function.lambda, aws_sns_topic.verification_notice]
  topic_arn  = aws_sns_topic.verification_notice.arn
  protocol   = "lambda"
  endpoint   = aws_lambda_function.lambda.arn
}