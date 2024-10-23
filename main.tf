/***********
Provider Configuration
************/

terraform { 
  required_providers { 
    aws = { 
      source  = "hashicorp/aws" 
      version = "~> 5.0" 
    } 
  } 
} 

provider "aws" { 
  region = "us-east-2"
    access_key = var.aws_access_key 
    secret_key = var.aws_secret_key 
} 

/***********
VPC Configuration
Create/Configure the VPC, Internet Gateway, Subnets, and Route Tables
************/

# VPC
resource "aws_vpc" "account_vpc" { 
  cidr_block = "10.0.0.0/16"
  tags = { Name = "account_vpc"}
} 

# INTERNET GATEWAY
resource "aws_internet_gateway" "account_igw" { 
  vpc_id = aws_vpc.account_vpc.id 
  tags = { Name = "account_igw" }
}

# PUBLIC SUBNET
resource "aws_subnet" "donuteast2a_public_sn" { 
  vpc_id            = aws_vpc.account_vpc.id 
  cidr_block        = "10.0.0.0/24" 
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true # Indicate that instances launched into the subnet should be assigned a public IP address
  tags = { Name = "donuteast2a_public_sn" }
} 

# PRIVATE SUBNET
resource "aws_subnet" "donuteast2b_private_sn" { 
  vpc_id            = aws_vpc.account_vpc.id 
  cidr_block        = "10.0.1.0/24" 
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = false 
  tags = { Name = "donuteast2b_private_sn" }
} 

# ROUTE TABLE FOR PUBLIC SUBNET
resource "aws_route_table" "account_route_table_pub" { 
  vpc_id = aws_vpc.account_vpc.id 
  tags = { Name = "account_route_table_pub" }
  
  # Route to the local VPC
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  # Route to the internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.account_igw.id
  }
} 

# ROUTE TABLE FOR PRIVATE SUBNET
resource "aws_route_table" "account_route_table_priv" { 
  vpc_id = aws_vpc.account_vpc.id 
  tags = { Name = "account_route_table_priv" }
  
  # Route to the local VPC
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }
} 

# ROUTE TABLE ASSOCIATION FOR PUBLIC SUBNET 
resource "aws_route_table_association" "subnet_a_route_table_association" { 
  subnet_id         = aws_subnet.donuteast2a_public_sn.id 
  route_table_id    = aws_route_table.account_route_table_pub.id 
} 

# ROUTE TABLE ASSOCIATION FOR PRIVATE SUBNET
resource "aws_route_table_association" "subnet_b_route_table_association" { 
  subnet_id         = aws_subnet.donuteast2b_private_sn.id 
  route_table_id    = aws_route_table.account_route_table_priv.id 
} 

/***********
Security Group Configuration
Create/Configure security groups for the web and database servers
************/

# WEB SECURITY GROUP
resource "aws_security_group" "web_security_group" { 
  name        = "sgaccountweb" 
  description = "Web security group that allows 443, 80, and 22" 
  vpc_id      = aws_vpc.account_vpc.id 
  tags = { Name = "sgaccountweb" }

  # Allow inbound web traffic with HTTPS
  ingress { 
    from_port   = 443 
    to_port     = 443 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  } 

  # Allow inbound web traffic with HTTP
  ingress { 
    from_port   = 80 
    to_port     = 80 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  } 

  # Allow inbound SSH traffic
  ingress { 
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] # Later change to specific IP?
  } 

  # Allow all outbound traffic
  egress { 
    from_port   = 0 
    to_port     = 0 
    protocol    = -1 
    cidr_blocks = ["0.0.0.0/0"] 
  } 
} 

# DATABASE SECURITY GROUP
resource "aws_security_group" "db_security_group" { 
  name        = "sgaccountdb" 
  description = "Database security group that allows 3306 and 22" 
  vpc_id      = aws_vpc.account_vpc.id 
  tags = { Name = "sgaccountdb" }

  # Allow inbound MySQL traffic
  ingress { 
    from_port   = 3306 
    to_port     = 3306 
    protocol    = "tcp" 
    cidr_blocks = ["10.0.0.0/16"] # Only allow traffic from the VPC
  } 

  # Allow inbound SSH traffic
  ingress { 
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] # Later change to specific IP?
  } 

  # Allow all outbound traffic
  egress { 
    from_port   = 0 
    to_port     = 0 
    protocol    = -1 
    cidr_blocks = ["0.0.0.0/0"] 
  } 
} 

/***********
EC2 Instance Configuration
************/

# EC2 INSTANCE FOR WEB SERVER
resource "aws_instance" "donutws" { 
  ami           = "ami-00dfe2c7ce89a450b" # Amazon Linux 2023 AMI
  instance_type = "t2.micro" 
  key_name     = "pdcserverkey" 
  subnet_id    = aws_subnet.donuteast2a_public_sn.id 
  security_groups = [aws_security_group.web_security_group.id] 
  tags = { Name = "Web Server" } 
  # TO ADD: USE GOLDEN IMAGE
} 

# ELASTIC IP FOR WEB SERVER
resource "aws_eip" "elastic_ip" { 
  vpc = true 
} 

/***********
RDS Configuration
************/

# RDS INSTANCE
resource "aws_db_instance" "donutdb" { 
  allocated_storage    = 20 
  storage_type         = "gp2" 
  engine               = "mysql" 
  engine_version       = "5.7" 
  instance_class       = "db.t2.micro"
  username             = "admin" 
  password             = "password" 
  db_subnet_group_name = "default" 
  vpc_security_group_ids = [aws_security_group.db_security_group.id] 
  tags = { Name = "donutdb" } 
}