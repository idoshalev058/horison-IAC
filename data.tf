# Find the existing VPC
data "aws_vpc" "existing_vpc" {
  filter {
    name   = "tag:Name"
    values = ["sandboxcyberengineering-prd-001-spoke-vpc"]
  }
}

# Find the specific Subnets inside the fetched VPC
data "aws_subnets" "existing_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing_vpc.id]
  }
  filter {
    name   = "tag:Name"
    values = [
      "SPOKE-Networking-328113723980-Stack/VPC/VPC/firewallSubnet1",
      "SPOKE-Networking-328113723980-Stack/VPC/VPC/spokeSubnet2"
    ]
  }
}

# Find the existing Security Group inside the fetched VPC
data "aws_security_group" "existing_sg" {
  filter {
    name   = "tag:Name"
    values = ["Allow Spoke"]
  }
  vpc_id = data.aws_vpc.existing_vpc.id
}