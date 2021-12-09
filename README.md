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


import certificate to AWS Certificate Manager

aws acm import-certificate --certificate fileb://prod_pengchengxu_me.crt \
      --certificate-chain fileb://prod_pengchengxu_me.ca-bundle \
      --private-key fileb://private.key 