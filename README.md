# infrastructure

The infrastructure will use the local aws configuration for provider

use Terraform plan and apply to create the new vpcs

you need to provide 
- profile name
- vpc cidr block
- subnet cidr block list
- route table cidr block
- route destination cidr block
in .tfvars file 