region                   = "us-east-1"
AZ                       = ["us-east-1b", "us-east-1c"]
public_subnet_cidr_block = ["10.0.10.0/24","10.0.20.0/24"]  
public_subnet            = ["awsezzie_public_subnet-1", "awsezzie_public_subnet-2" ]
route_table              = [{ cidr_block = "0.0.0.0/0", name = "awsezzie_route_table_public" }]
counts                   = 2
ec2_instance             = ["awsezzie-1","awsezzie-2"]