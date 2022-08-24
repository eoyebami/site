provider "aws" {
    region = var.region
}

#Creating a vpc
resource "aws_vpc" "awsezzie_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

#Creating a public subnet for the in AZs
resource "aws_subnet" "awsezzie_subnet" {
  vpc_id     = aws_vpc.awsezzie_vpc.id
  cidr_block = var.public_subnet_cidr_block[count.index]
  count = 2 
  availability_zone = var.AZ[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.public_subnet[count.index]}"
  }
}

#resource "aws_subnet" "awsezzie_subnet-2" {
#  vpc_id     = aws_vpc.awsezzie_vpc.id
#  cidr_block = var.public_subnet_cidr_block[1]
#  availability_zone = var.AZ[1]
#  map_public_ip_on_launch = true
#  tags = {
#    Name = var.public_subnet[1]
#}
#}

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
    cidr_block = var.route_table[0].cidr_block
    gateway_id = aws_internet_gateway.awsezzie_gw.id
  }

  tags = {
    Name = "${var.route_table[0].name}"
  }
}

#Associate route table to public subnets
resource "aws_route_table_association" "a" {
  count = 2
  subnet_id      = "${aws_subnet.awsezzie_subnet[count.index].id}"
  route_table_id = aws_route_table.awsezzie_route_table_public.id
}

#resource "aws_route_table_association" "b" {
#  subnet_id      = aws_subnet.awsezzie_subnet-2.id
#  route_table_id = aws_route_table.awsezzie_route_table_public.id
#}

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
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
 
  ingress {
    description = "EFS mount target"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

#Creeate tls secret key
resource "tls_private_key" "site_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "sitekeypair" {
  key_name   = "site_key"
  public_key = tls_private_key.site_key.public_key_openssh
}

resource "local_file" "site_key" {
  filename = "site_key.pem"
  content = tls_private_key.site_key.private_key_pem
}

#data "aws_key_pair" "awskeypair" {
#  key_name           = "awskeypair"
#  include_public_key = true
#}

#resource "local_file" "awskeypair" {
#  filename = "awskeypair.pem"
#  content = tls_private_key.site_key.private_key_pem
#}

#Create instances within the public subnets
resource "aws_instance" "awsezzie" {
    ami = "ami-090fa75af13c156b4"
    instance_type = "t2.micro"
    availability_zone = var.AZ[count.index]
    key_name = "site_key"
    count = 2
    vpc_security_group_ids = [ aws_security_group.allow_web_traffic.id ]
    subnet_id = "${aws_subnet.awsezzie_subnet[count.index].id}"
    tags = {
    Name = "${var.ec2_instance[count.index]}"
  }
  provisioner "remote-exec" {
         inline = [ 
        "#!/bin/bash",
        "sudo yum update -y",
        "sudo yum install httpd -y",
        "sudo systemctl start httpd",
        "sudo systemctl enable httpd",
        "sudo yum install git -y",
        "sudo chown -R $USER:$USER /var/www",
        "sudo rm -rf /var/www/html/*",
        "git clone https://github.com/eoyebami/project-website-template.git /var/www/html/.",
      ] 
  connection {
    type = "ssh"
    user = "ec2-user"
    private_key = tls_private_key.site_key.private_key_pem
    host = "${self.public_ip}"
     }
   }
  }  

#resource "aws_instance" "awsezzie-2" {
#    ami = "ami-090fa75af13c156b4"
#    instance_type = "t2.micro"
#    availability_zone = var.AZ[1].availability_zone
#    key_name = "site_key"
#    vpc_security_group_ids = [ aws_security_group.allow_web_traffic.id ]
#    subnet_id = aws_subnet.awsezzie_subnet-2.id 
#  provisioner "remote-exec" {
#      inline = [ 
#        "#!/bin/bash",
#        "sudo yum update -y",
#        "sudo yum install httpd -y",
#        "sudo systemctl start httpd",
#        "sudo systemctl enable httpd",
#        "sudo yum install git -y",
#        "sudo yum install wget -y",
#        "sudo yum install unzip -y",
#        "wget https://www.free-css.com/assets/files/free-css-templates/download/page281/cs.zip",
#        "unzip cs.zip",
#        "sudo chown -R $USER:$USER /var/www",
#        "sudo rm -rf /var/www/html/*",
#        "cp -r cs/* /var/www/html/.",
#      ] 
#  connection {
#    type = "ssh"
#    user = "ec2-user"
#    private_key = tls_private_key.site_key.private_key_pem
#    host = aws_instance.awsezzie-2.public_ip
#     }
#   }
#  }  

#Creating Load Balance for both instances
resource "aws_lb" "awsezzie_lb" {
  name               = "awsezzie-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_web_traffic.id]
  subnets            = [aws_subnet.awsezzie_subnet[0].id, aws_subnet.awsezzie_subnet[1].id]

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
  count = var.counts
  target_group_arn = aws_lb_target_group.awsezzie_lb_tg.arn
  target_id        = "${aws_instance.awsezzie[count.index].id}"
  port             = 80
}

#resource "aws_lb_target_group_attachment" "test-2" {
#  target_group_arn = aws_lb_target_group.awsezzie_lb_tg.arn
#  target_id        = aws_instance.awsezzie-2.id
#  port             = 80
#}

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

resource "aws_lb_listener" "HTTPS" {
  load_balancer_arn = aws_lb.awsezzie_lb.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate_validation.CNAME_validate.certificate_arn
 
  
   default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.awsezzie_lb_tg.arn
  }
}

#Create a hosted zone in Route 53
data "aws_route53_zone" "awsezzie" {
  name         = "awsezzie.com"
  private_zone = false
}

#Create a certicate for the domain 
resource "aws_acm_certificate" "cert" {
  domain_name       = "elb.awsezzie.com"
  validation_method = "DNS"
  subject_alternative_names = [ "awsezzie.com" ]

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "CNAME" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.awsezzie.id
}

resource "aws_acm_certificate_validation" "CNAME_validate" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.CNAME : record.fqdn]
}

#Create an A recorded connecting the lb to the domain
resource "aws_route53_record" "lb_record" {
  zone_id = data.aws_route53_zone.awsezzie.id
  name    = "elb.awsezzie.com"
  type    = "A"

  alias {
    name                   = aws_lb.awsezzie_lb.dns_name
    zone_id                = aws_lb.awsezzie_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "lb_record_2" {
  zone_id = data.aws_route53_zone.awsezzie.id
  name    = "awsezzie.com"
  type    = "A"

  alias {
    name                   = aws_lb.awsezzie_lb.dns_name
    zone_id                = aws_lb.awsezzie_lb.zone_id
    evaluate_target_health = true
  }
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.awsezzie_lb.dns_name
}
