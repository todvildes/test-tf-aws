provider "aws" {
  version = "~> 2.0"
  region     = var.region
}

terraform {
  backend "s3" {
    bucket         = "sts-casino-dev-state-file"
    dynamodb_table = "desi-test-state-lock"
    key            = "state-file-desi-test/terraform.tfstate"
    region         = "us-east-1"
  }
}

# create the VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpcCIDRblock
} # end resource

# create the Subnet
resource "aws_subnet" "my_vpc_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = var.subnetCIDRblock
  map_public_ip_on_launch = var.mapPublicIP
  availability_zone       = var.availabilityZone
  tags = {
    Name = "desi-test-subnet"
  }
} # end resource

# Create the Security Group
resource "aws_security_group" "my_vpc_security_group" {
  vpc_id      = aws_vpc.my_vpc.id
  name        = "desi-test-security-group"
  description = "desi-test-security-group"

  # allow ingress of port 22
  ingress {
    cidr_blocks = var.ingressCIDRblock
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  # allow egress of all ports
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "desi-test-securitygroup"
    Description = "desi-test-security-group"
  }
} # end resource

# create VPC Network access control list
resource "aws_network_acl" "my_vpc_security_acl" {
  vpc_id     = aws_vpc.my_vpc.id
  subnet_ids = [aws_subnet.my_vpc_subnet.id] # allow ingress port 22
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 22
    to_port    = 22
  }

  # allow ingress port 80 
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 80
    to_port    = 80
  }

  # allow ingress ephemeral ports 
  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 1024
    to_port    = 65535
  }

  # allow egress port 22 
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 22
    to_port    = 22
  }

  # allow egress port 80 
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 80
    to_port    = 80
  }

  # allow egress ephemeral ports
  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = var.destinationCIDRblock
    from_port  = 1024
    to_port    = 65535
  }
  tags = {
    Name = "desi-test-vpc-acl"
  }
} # end resource

# Create the Internet Gateway
resource "aws_internet_gateway" "my_vpc_gw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "desi-test-vpc-internet-gateway"
  }
} # end resource

# Create the Route Table
resource "aws_route_table" "my_vpc_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "desi-test-vpc-route-table"
  }
} # end resource

# Create the Internet Access
resource "aws_route" "my_vpc_internet_access" {
  route_table_id         = aws_route_table.my_vpc_route_table.id
  destination_cidr_block = var.destinationCIDRblock
  gateway_id             = aws_internet_gateway.my_vpc_gw.id
} # end resource

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "my_vpc_association" {
  subnet_id      = aws_subnet.my_vpc_subnet.id
  route_table_id = aws_route_table.my_vpc_route_table.id
} # end resource

#Amazon Linux AMI
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners = [ "amazon" ]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
} # end data

#ssh
resource "aws_key_pair" "ssh-key" {
  key_name   = "ssh-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDJyXWKwAHMr2TNRWoR5dIIvyFvlKIHyTbAZ2seBICWYGN0xvBSHQv0uD89ZKIfDmhYwU/VtkNSRGGI6MvTEaPAPDCV9x0aZJMC+N2jjYU9p5j3W30bPuT7YVl7hQ7/RBZIhT3UNMxR9pO9lECbhWU/FhvBjSTPLyWULWhn3KHtAB4TjmvCUSO3dpZAzhPTNKJuL0hcZ+RHRGIRQBJmecr37MpBXqkJEFbmZKPiYlhL1G8ohWc6zatUN8acXyhAwesMdYqDTm4qMdN1cunSUT+2zpYE/D4FhsJW6VSE21p51C7i4u6bNnqDUjaZOPPvw8Zl906JbDZ3nXmhAZT4Yl9SS/bN8nQRBiEEG6kqElbXyec+MaS7T5BK0oztpknntWm+bEGc9N6NXRmpUmbb7kobipLeH3eoVuA3mr1/l9WLlLKCdIjTOxLPvrUqSGRRUlUF2ENitZVVjnbRiHATnZxazwQdJrn+MWp2Vp0BVwg3EtiMvWETaILX1Q1bsQivDss= desislavat@BUL0002176.local"
} #end resource

#EC2
resource "aws_instance" "my_ec2" {
  ami                         = data.aws_ami.amazon-linux-2.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  vpc_security_group_ids = [aws_security_group.my_vpc_security_group.id]  
  subnet_id = aws_subnet.my_vpc_subnet.id
  key_name         = "ssh-key"
} #end resource

output "instance_ip" {
  description = "The public ip for ssh access"
  value       = aws_instance.my_ec2.public_ip
} # end output

#ElasticIP
resource "aws_eip" "my_eip" {
  vpc      = true
  instance = aws_instance.my_ec2.id
} #end resource


