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

# Create the VPC
resource "aws_vpc" "account_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create the internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.account_vpc.id
}

# Create NACLs
resource "aws_network_acl" "web_server_nacl" {
  vpc_id = aws_vpc.account_vpc.id
    egress {
    rule_no = 100
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  egress {
    rule_no = 101
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }

  egress {
    rule_no = 102
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_block = "0.0.0.0/0"
    action = "allow"
    }
}

resource "aws_network_acl" "database_nacl" {
  vpc_id = aws_vpc.account_vpc.id
    egress {
    rule_no = 100
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_block = "0.0.0.0/0"
    action = "allow"
  }
}

# Define NACL rules
resource "aws_network_acl_rule" "web_server_inbound_allow_ssh" {
  network_acl_id = aws_network_acl.web_server_nacl.id
  rule_number = 200
  rule_action = "allow"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_block  = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "web_server_inbound_allow_http" {
  network_acl_id = aws_network_acl.web_server_nacl.id
  rule_number = 201
  rule_action = "allow"
  protocol    = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_block  = "0.0.0.0/0"
}

resource "aws_network_acl_rule" "web_server_inbound_allow_https" {
  network_acl_id = aws_network_acl.web_server_nacl.id
  rule_number = 202
  rule_action = "allow"
  protocol    = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_block  = "0.0.0.0/0"
}

# Create the first subnet (public)
resource "aws_subnet" "donuteast2a_public_sn" {
  vpc_id            = aws_vpc.account_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-2a" 
  map_public_ip_on_launch = true
}

# Create the second subnet (private)
resource "aws_subnet" "donuteast2b_private_sn" {
  vpc_id            = aws_vpc.account_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-2b" 
  map_public_ip_on_launch = false
}

# And another for use with the RDS instance
resource "aws_subnet" "donuteast2a_private_sn" {
  vpc_id            = aws_vpc.account_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-2a" 
  map_public_ip_on_launch = false
}

# Create subnet group for use with the RDS instance
resource "aws_db_subnet_group" "donutdb_subnet_group" {
  name        = "donutdb_subnet_group"
  description = "Subnet group for my RDS database"
  subnet_ids = [
    aws_subnet.donuteast2b_private_sn.id,
    aws_subnet.donuteast2a_private_sn.id
  ]
}

resource "aws_network_acl_association" "web_server_nacl_association" {
  subnet_id        = aws_subnet.donuteast2a_public_sn.id
  network_acl_id   = aws_network_acl.web_server_nacl.id
}

resource "aws_network_acl_association" "db_server_nacl_association" {
  subnet_id        = aws_subnet.donuteast2b_private_sn.id
  network_acl_id   = aws_network_acl.database_nacl.id
}

resource "aws_network_acl_association" "db_server_nacl_association2" {
  subnet_id        = aws_subnet.donuteast2a_private_sn.id
  network_acl_id   = aws_network_acl.database_nacl.id
}

# Create the public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.account_vpc.id
}

# Create the private route table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.account_vpc.id
}

# Create the route
resource "aws_route" "internet_route" {
  route_table_id     = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id         = aws_internet_gateway.internet_gateway.id
}

# Create the subnet route table associations
resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id         = aws_subnet.donuteast2a_public_sn.id
  route_table_id    = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_1" {
  subnet_id         = aws_subnet.donuteast2b_private_sn.id
  route_table_id    = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_route_table_association_2" {
  subnet_id         = aws_subnet.donuteast2a_private_sn.id
  route_table_id    = aws_route_table.private_route_table.id
}

# Create the web security group
resource "aws_security_group" "web_security_group" {
  name        = "Web security group"
  description = "Web security group that allows 443, 80, and 22"
  vpc_id      = aws_vpc.account_vpc.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the database security group
resource "aws_security_group" "db_security_group" {
  name        = "Database security group"
  description = "Database security group that allows 3306 and 22"
  vpc_id      = aws_vpc.account_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the web server instance
resource "aws_instance" "donutws" {
  ami           = "ami-0639e0efdfb312b12"
  instance_type = "t2.micro"
  key_name     = "pdcserverkey"
  subnet_id    = aws_subnet.donuteast2a_public_sn.id
  security_groups = [aws_security_group.web_security_group.id]

  tags = {
    Name = "Web Server"
  }

    user_data = <<EOF
#!/bin/bash
sudo systemctl start nginx
EOF
}

# Create the elastic IP
resource "aws_eip" "elastic_ip" {
  vpc = true
}

# RDS INSTANCE
resource "aws_db_instance" "donutdb" { 
  allocated_storage    = 20 
  storage_type         = "gp2" 
  engine               = "mysql" 
  engine_version       = "8.0.39" 
  instance_class       = "db.m5.large"
  username             = "admin" 
  password             = "password" 
  db_subnet_group_name = "donutdb_subnet_group" 
  vpc_security_group_ids = [aws_security_group.db_security_group.id] 
  skip_final_snapshot = true
  tags = { Name = "donutdb" } 
}