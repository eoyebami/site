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
resource "aws_subnet" "awsezzie_nat_subnet-1" {
  vpc_id     = aws_vpc.awsezzie_vpc.id
  cidr_block = "10.0.100.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "awsezzie_nat_subnet-1"
  }
}

resource "aws_subnet" "awsezzie_nat_subnet-2" {
  vpc_id     = aws_vpc.awsezzie_vpc.id
  cidr_block = "10.0.200.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "awsezzie_nat_subnet-2"
  }
}

#Creating a private subnet for web servers
resource "aws_subnet" "awsezzie_private_web_subnet-1" {
  vpc_id     = aws_vpc.awsezzie_vpc.id
  cidr_block = "10.0.20.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "awsezzie_private_web_subnet-1"
  }
}

resource "aws_subnet" "awsezzie_private_web_subnet-2" {
  vpc_id     = aws_vpc.awsezzie_vpc.id
  cidr_block = "10.0.30.0/24"
  availability_zone = "us-east-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "awsezzie_private_web_subnet-2"
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
  subnet_id      = aws_subnet.awsezzie_nat_subnet-1.id
  route_table_id = aws_route_table.awsezzie_route_table_public.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.awsezzie_nat_subnet-2.id
  route_table_id = aws_route_table.awsezzie_route_table_public.id
}

#Create an elastic ip for the nat gateway
resource "aws_eip" "nat_eip-1" {
  vpc      = true
  depends_on = [aws_internet_gateway.awsezzie_gw]
}

resource "aws_eip" "nat_eip-2" {
  vpc      = true
  depends_on = [aws_internet_gateway.awsezzie_gw]
}

#Create nat gateway and allocate eip
resource "aws_nat_gateway" "awsezzie_nat_gateway-1" {
  allocation_id = aws_eip.nat_eip-1.id
  subnet_id     = aws_subnet.awsezzie_nat_subnet-1.id

  tags = {
    Name = "awsezzie_nat_gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.awsezzie_gw]
}

resource "aws_nat_gateway" "awsezzie_nat_gateway-2" {
  allocation_id = aws_eip.nat_eip-2.id
  subnet_id     = aws_subnet.awsezzie_nat_subnet-2.id

  tags = {
    Name = "awsezzie_nat_gw"
  }
 # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.awsezzie_gw]
}

#Route table to private subnets
resource "aws_route_table" "awsezzie_route_table_private-1" {
  vpc_id = aws_vpc.awsezzie_vpc.id

  route {
    cidr_block = "10.0.100.0/24"
    gateway_id = aws_nat_gateway.awsezzie_nat_gateway-1.id
  }
  tags = {
    Name = "awsezzie_route_table_private"
  }
}

resource "aws_route_table" "awsezzie_route_table_private-2" {
  vpc_id = aws_vpc.awsezzie_vpc.id

  route {
    cidr_block = "10.0.200.0/24"
    gateway_id = aws_nat_gateway.awsezzie_nat_gateway-2.id
  }

  tags = {
    Name = "awsezzie_route_table_private"
  }
}


#Connect route table to private subnets
resource "aws_route_table_association" "web-a" {
  subnet_id      = aws_subnet.awsezzie_private_web_subnet-1.id
  route_table_id = aws_route_table.awsezzie_route_table_private-1.id
}

resource "aws_route_table_association" "web-b" {
  subnet_id      = aws_subnet.awsezzie_private_web_subnet-2.id
  route_table_id = aws_route_table.awsezzie_route_table_private-2.id
}

#Creat security group for the lb in the public subnet
resource "aws_security_group" "allow_web_to_lb" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.awsezzie_vpc.id

  ingress {
    description      = "Allow Web"
    from_port        = 80
    to_port          = 80
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
    Name = "allow_web_to_lb"
  }
}
#Create security group for instances within the private subnets
resource "aws_security_group" "allow_web_traffic_from_lb" {
  name        = "allow_web_traffic_lb"
  description = "Allow web inbound traffic from LB"
  vpc_id      = aws_vpc.awsezzie_vpc.id

  ingress {
    description      = "HTTPS from LB"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups = [aws_security_group.allow_web_to_lb.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_from_lb"
  }
}

#Create instances within the private subnets
resource "aws_instance" "awsezzie-1" {
    ami = "ami-090fa75af13c156b4"
    instance_type = "t2.micro"
    availability_zone = "us-east-1b" 
    key_name = "awskeypair"
    vpc_security_group_ids = [ aws_security_group.allow_web_traffic_from_lb.id ]
    subnet_id = aws_subnet.awsezzie_private_web_subnet-1.id
    user_data = <<EOF
    #!/bin/bash
    sudo yum update
    sudo yum install httpd -y
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "My first server" > /var/www/html/index.html
    EOF
}

resource "aws_instance" "awsezzie-2" {
    ami = "ami-090fa75af13c156b4"
    instance_type = "t2.micro"
    availability_zone = "us-east-1c"
    key_name = "awskeypair"
    vpc_security_group_ids = [ aws_security_group.allow_web_traffic_from_lb.id ]
    subnet_id = aws_subnet.awsezzie_private_web_subnet-2.id
     user_data = <<EOF
    #!/bin/bash
    sudo yum update
    sudo yum install httpd -y
    sudo systemctl start httpd
    sudo systemctl enable httpd
    echo "My first server" > /var/www/html/index.html
    EOF
}

#Creating Load Balance for both instances
resource "aws_lb" "awsezzie_lb" {
  name               = "awsezzie-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_to_lb.id]
  subnets            = [aws_subnet.awsezzie_nat_subnet-1.id, aws_subnet.awsezzie_nat_subnet-2.id]
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

resource "aws_lb_listener" "front_end" {
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