output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "subnet_id_list" {
  value = [for k, v in aws_subnet.subnet : v.id]
}

output "internet_gateway_id" {
  value = aws_internet_gateway.internet_gateway.id
}

output "route_table_id" {
  value = aws_route_table.route_table.id
}

output "bucket" {
  value = aws_s3_bucket.bucket.bucket
}

output "rds" {
  value = aws_db_instance.db_instance.endpoint
}
