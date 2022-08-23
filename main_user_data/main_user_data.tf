provider "aws" {
    region = "us-east-1"
}

#Creating a vpc
resource "aws_vpc" "awsezzie_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

#Creating a public subnet for the nat gateway in az-1
resource "aws_subnet" "awsezzie_subnet-1" {
  vpc_id     = aws_vpc.awsezzie_vpc.id
  cidr_block = "10.0.10.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "awsezzie_nat_subnet-1"
  }
}

#Creating a private subnet for web servers
resource "aws_subnet" "awsezzie_subnet-2" {
  vpc_id     = aws_vpc.awsezzie_vpc.id
  cidr_block = "10.0.20.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "awsezzie_private_web_subnet-1"
  }
}

#Creating an internet gateway for the vpc
resource "aws_internet_gateway" "awsezzie_gw" {
  vpc_id = aws_vpc.awsezzie_vpc.id

  tags = {
    Name = "awsezzie_gw"
  }
}

#Creating a route table for public subnets
resource "aws_route_table" "awsezzie_route_table_public" {
  vpc_id = aws_vpc.awsezzie_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.awsezzie_gw.id
  }

  tags = {
    Name = "awsezzie_route_table_public"
  }
}

#Associate route table to public subnets
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.awsezzie_subnet-1.id
  route_table_id = aws_route_table.awsezzie_route_table_public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.awsezzie_subnet-2.id
  route_table_id = aws_route_table.awsezzie_route_table_public.id
}

#Create security group for instances within the public subnets
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.awsezzie_vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "SS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Create instances within the public subnets
resource "aws_instance" "awsezzie-1" {
    ami = "ami-090fa75af13c156b4"
    instance_type = "t2.micro"
    availability_zone = "us-east-1b" 
    key_name = "awskeypair"
    vpc_security_group_ids = [ aws_security_group.allow_web_traffic.id ]
    subnet_id = aws_subnet.awsezzie_subnet-1.id
    user_data = <<EOF
    #!/bin/bash
    sudo yum update
    sudo yum install httpd -y
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "Welcome to my School Site" > /var/www/html/index.html
    EOF
}

resource "aws_instance" "awsezzie-2" {
    ami = "ami-090fa75af13c156b4"
    instance_type = "t2.micro"
    availability_zone = "us-east-1c"
    key_name = "awskeypair"
    vpc_security_group_ids = [ aws_security_group.allow_web_traffic.id ]
    subnet_id = aws_subnet.awsezzie_subnet-2.id
     user_data = <<EOF
    #!/bin/bash
    sudo yum update
    sudo yum install httpd -y
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "Welcome to my School Site" > /var/www/html/index.html
    EOF
}

#Creating Load Balance for both instances
resource "aws_lb" "awsezzie_lb" {
  name               = "awsezzie-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_traffic.id]
  subnets            = [aws_subnet.awsezzie_subnet-1.id, aws_subnet.awsezzie_subnet-2.id]

  enable_deletion_protection = false
}

#Create target groupds for lb
resource "aws_lb_target_group" "awsezzie_lb_tg" {
  name     = "awsezzie-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.awsezzie_vpc.id
}

#attaching resources into the target group
resource "aws_lb_target_group_attachment" "test-1" {
  target_group_arn = aws_lb_target_group.awsezzie_lb_tg.arn
  target_id        = aws_instance.awsezzie-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test-2" {
  target_group_arn = aws_lb_target_group.awsezzie_lb_tg.arn
  target_id        = aws_instance.awsezzie-2.id
  port             = 80
}

#Attaching target group to lb
resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.awsezzie_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.awsezzie_lb_tg.arn
  }
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.awsezzie_lb.dns_name
}
