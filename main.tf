provider "aws" {
  region  = "us-east-1"
  shared_credentials_files = ["/home/ubuntu/.aws/credentials"]
}

resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# Create Route Table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# Subnet creation
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"  # Change as needed
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allows SSH from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_eip" "netspi_eip" {
  filter {
    name   = "tag:Project"
    values = ["NetSPI_EIP"]
  }
}


# S3 Bucket for netspi
resource "aws_s3_bucket" "netspi_bucket" {
  bucket = "netspi-efs-bucket-assignment"

  #acl    = "private"

  tags = {
    Name = "NetSPI_EFS_Bucket"
  }
}

# aws_s3_bucket_ownership_controls Provides a resource to manage S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "netspi_bucket_ownership" {
  bucket = aws_s3_bucket.netspi_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# acl for s3 bucket
resource "aws_s3_bucket_acl" "netspi_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.netspi_bucket_ownership]

  bucket = aws_s3_bucket.netspi_bucket.id
  acl    = "private"
}

# EFS creation with tag
resource "aws_efs_file_system" "efs" {
  encrypted = true
  tags = {
    Name = "NetSPI_EFS"
  }
}

#  Mount EFS Target
resource "aws_efs_mount_target" "efs_mount" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.main_subnet.id
  security_groups = [aws_security_group.ec2_sg.id]
}

#Generate an SSH key pair
resource "tls_private_key" "ec2_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# create key

resource "aws_key_pair" "milind_key_pair" {
  key_name   = "my-key"
  public_key = tls_private_key.ec2_key_pair.public_key_openssh
}

# EC2 Instance creation
resource "aws_instance" "ec2_instance" {
  name          = var.instance_name
  ami           ="ami-0ebfd941bbafe70c6"
  instance_type = "t2.micro"

  key_name = aws_key_pair.milind_key_pair.key_name

  subnet_id              = aws_subnet.main_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  user_data = file("ec2_bootstrap.sh")

  tags = {
    Name = "NetSPI_EC2_Instance"
  }
}

# Attach Elastic IP to EC2
resource "aws_eip_association" "ec2_eip" {
  instance_id   = aws_instance.ec2_instance.id
  allocation_id = data.aws_eip.netspi_eip.id
}
