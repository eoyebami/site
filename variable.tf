variable "region" {
  type    = string
  default = "us-east-1"
}

variable "AZ" {
  type    = list(any)
  default = ["us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidr_block" {
  type    = list(any)
  default = ["10.0.10.0/24","10.0.20.0/24"]
}

variable "public_subnet" {
  type = list
  default = ["awsezzie_public_subnet-1", "awsezzie_public_subnet-2" ]
}

variable "route_table" {
  type    = list(any)
  default = [{ cidr_block = "0.0.0.0/0", name = "awsezzie_route_table_public" }]
}

variable "counts" {
  type    = any
  default = 2
}

variable "ec2_instance" {
  type = list
  default = ["awsezzie-1", "awsezzie-2"]
}