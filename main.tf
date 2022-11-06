provider "aws" {
    region = "eu-north-1"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable "instance_type" {}
# variable "my_public_key" {}
variable "public_key_path" {}



resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name = "${var.env_prefix}-subnet-1"
  }
}

//Creating Internet gateway
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name = "${var.env_prefix}-igw"
  }
}


//creating route table
resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  //defining the route table
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}

# //Using default route table
# /*resource "aws_default_route_table" "main-rtb" {
#   default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.myapp-igw.id
#   }
#   tags = {
#     Name = "${var.env_prefix}-main-rtb"
#   }
# }
# */

//Associating subnet with rtb created
resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_route_table.myapp-route-table.id
  
}

//create SG to open port 22 & 8080
resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"
  vpc_id = aws_vpc.myapp-vpc.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }

}

# //using default SG
# /* resource "aws_default_security_group" "default-sg" {
#   vpc_id = aws_vpc.myapp-vpc.id

#   ingress {
#     from_port = 22
#     to_port = 22
#     protocol = "tcp"
#     cidr_blocks = [var.my_ip]
#   }

#   ingress {
#     from_port = 8080
#     to_port = 8080
#     protocol = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#     prefix_list_ids = []
#   }

#   tags = {
#     Name = "${var.env_prefix}default-sg"
#   }

# }
# */

//setting AMI dynamically
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true
  owners = [ "amazon" ]
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = [ "hvm" ]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}
output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

# Automate creating of ssh key pair
resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
#   public_key = var.my_public_key
  
#  More better to use file fetch
  public_key = file(var.public_key_path)
}

//Creating ec2 instance
resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amazon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]
    availability_zone = var.avail_zone

    associate_public_ip_address = true
    # key_name = "server-key-pair"
    key_name = aws_key_pair.ssh-key.key_name


# Running entry script for updates and install docker
#    user_data = file("entry-script.sh")
user_data = <<EOF
                 #!/bin/bash
                 sudo yum update -y && sudo yum install -y docker
                 sudo systemctl start docker
                 sudo usermod -aG docker ec2-user
                 docker run -p 8080:80 nginx
            EOF

    tags = {
        Name = "${var.env_prefix}-server"
    }

}