provider "aws" {
  region = "us-east-1"
}
# create vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }

}

# create Internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# Create custom route table
resource "aws_route_table" "main-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id

  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id


  }
  tags = {
    Name = "prod"
  }
}

# create a subnet
resource "aws_subnet" "pord-subnet" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.az

  tags = {
    Name = "prod-subnet"
  }
}

# Associate subnet with route table
resource "aws_route_table_association" "subnet-attach" {
  subnet_id      = aws_subnet.pord-subnet.id
  route_table_id = aws_route_table.main-route-table.id

}

# Create security group to allow port 22, 80,443
resource "aws_security_group" "allow_web" {
  name        = "allow web traffic"
  description = "allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id
  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "allow_web"
  }

}

# create a network interface with an ip in the subnet that was created earlier
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.pord-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an elastic IP to the network interface created earlier
resource "aws_eip" "public_ip" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw, aws_network_interface.web-server-nic]
}
# create ubuntu server and install/enable apache2
resource "aws_instance" "web_instance" {
  ami               = "ami-00874d747dde814fa"
  instance_type     = "t2.micro"
  availability_zone = var.az
  key_name          = "main-key"
  network_interface {

    device_index         = 0
    network_interface_id = aws_network_interface.web-server-nic.id

  }
  user_data = <<-EOF
       #!/bin/bash
       sudo apt update -y
       sudo apt install apache2 -y
       sudo systemctl start apache2
       sudo bash -c "echo 'your very first webserver' > /var/www/html/index.html"
       EOF

  tags = {
    Name = "ubuntu_web_server"
  }
}


output "public_ipaddress" {
  value = aws_eip.public_ip.public_ip
}

variable "az" {
  description = "availabilty zone"
  default = "us-east-1b"
  type = string
}