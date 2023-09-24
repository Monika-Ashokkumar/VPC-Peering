module "west_vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  providers = {
    aws = aws.west
  }
  
  name = "kc-west-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-1a", "us-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

module "east_vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  providers = {
    aws = aws.east
  }

  name = "ks-east-vpc"
  cidr = "10.1.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.3.0/24", "10.1.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

resource "aws_security_group" "allow_ssh_west" {
  name        = "allow_ssh_west"
  description = "Allow SSH inbound traffic for West VPC"
  depends_on = [module.west_vpc]
  vpc_id      = module.west_vpc.vpc_id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_ssh_east" {
  name        = "allow_ssh_east"
  description = "Allow SSH inbound traffic for East VPC"
  depends_on = [module.east_vpc]
  vpc_id      = module.east_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_peering_connection" "peer" {
  provider = aws.west

  vpc_id        = module.west_vpc.vpc_id
  peer_vpc_id   = module.east_vpc.vpc_id
  peer_region   = "us-east-1"
}
resource "aws_vpc_peering_connection_accepter" "peer_accept" {
  provider = aws.east

  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  auto_accept               = true

  tags = {
    Side = "Accepter"
  }
}

# Routes in Route Tables for VPC Peering
# For VPC in the West
resource "aws_route" "west_to_east" {
  provider                   = aws.west
  route_table_id             = module.west_vpc.private_route_table_ids[0] # Assuming the first route table, adjust as needed
  destination_cidr_block     = "10.1.0.0/16" # CIDR of VPC in the East
  vpc_peering_connection_id  = aws_vpc_peering_connection.peer.id
}

# For VPC in the East
resource "aws_route" "east_to_west" {
  provider                   = aws.east
  route_table_id             = module.east_vpc.private_route_table_ids[0] # Assuming the first route table, adjust as needed
  destination_cidr_block     = "10.0.0.0/16" # CIDR of VPC in the West
  vpc_peering_connection_id  = aws_vpc_peering_connection.peer.id
}


resource "aws_instance" "west_instance" {
  provider = aws.west
  depends_on = [module.west_vpc]
  key_name =    "ks-west-monika-vpcpeering"
  ami           = "ami-06d2c6c1b5cbaee5f" # replace with a valid AMI ID
  instance_type = "t2.micro"
  subnet_id     = module.west_vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.allow_ssh_west.id]
  associate_public_ip_address = true

  tags = {
    Name = "KS-Peering-West"
  }
}

resource "aws_instance" "east_instance" {
  provider = aws.east
  depends_on = [module.east_vpc]
  key_name = "ks-east-monika-vpcpeering"
  ami           = "ami-03a6eaae9938c858c" # replace with a valid AMI ID
  instance_type = "t2.micro"
  subnet_id     = module.east_vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.allow_ssh_east.id]
  associate_public_ip_address = true

  tags = {
    Name = "KS-Perring-East"
  }
}
