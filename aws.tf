provider "aws" {
    access_key = "XXXXXX"   # Enter AWS Access key here
    secret_key = "XXXXXXX"  # Enter AWS Secret key here
    region = "us-west-1"    # Enter the region name here
}

variable "availability_zone" {default = "us-west-1a"}
variable "network_ipv4" {default = "192.168.0.0/16"}
variable "long_name" {default = "micro-inf"}
variable "network_subnet_ip4" {default = "192.168.1.0/16"}
variable "node_count" {default = "1"}
variable "node_data_volume_size" {default = "20"} # size is in gigabytes
variable "node_type" {default = "t2.micro"}
variable "short_name" {default = "mi"}
variable "source_ami" {default = "ami-d1315fb1"}
variable "datacenter" {default = "aws"}

resource "aws_vpc" "main_network" {
  cidr_block = "${var.network_ipv4}"
  enable_dns_hostnames = true
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_subnet" "main_subnet" {
  vpc_id = "${aws_vpc.main_network.id}"
  cidr_block = "${var.network_subnet_ip4}"
  availability_zone = "${var.availability_zone}"
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_internet_gateway" "inet_gateway" {
  vpc_id = "${aws_vpc.main_network.id}"
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_route_table" "router_table" {
  vpc_id = "${aws_vpc.main_network.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.inet_gateway.id}"
  }

  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_main_route_table_association" "router_table_assoc" {
  vpc_id = "${aws_vpc.main_network.id}"
  route_table_id = "${aws_route_table.router_table.id}"
}

resource "aws_ebs_volume" "mi-tflearn-lvm" {
  availability_zone = "${var.availability_zone}"
  count = "${var.node_count}"
  size = "${var.node_data_volume_size}"
  type = "gp2"

  tags {
    Name = "${var.short_name}-vol-lvm-${format("%02d", count.index)}"
  }
}

resource "aws_instance" "tflearn" {
  ami = "${var.source_ami}"
  availability_zone = "${var.availability_zone}"
  instance_type = "${var.node_type}"
  count = "${var.node_count}"
  associate_public_ip_address = true

  vpc_security_group_ids = ["${aws_security_group.sec-groups.id}",
  "${aws_vpc.main_network.default_security_group_id}"]
   
  subnet_id = "${aws_subnet.main_subnet.id}"
  root_block_device {
    delete_on_termination = true
    volume_size = "${var.node_data_volume_size}"
  }

  tags {
    Name = "${var.short_name}-node-${format("%02d", count.index+1)}"
    role = "tflearn"
    dc = "${var.datacenter}"
  }
}

resource "aws_volume_attachment" "mi-nodes-lvm-attachment" {
  count = "${var.node_count}"
  device_name = "/dev/sdh"
  instance_id = "${aws_instance.tflearn.id}"
  volume_id = "${aws_ebs_volume.mi-tflearn-lvm.id}"
  force_detach = true
}

resource "aws_security_group" "sec-groups" {
  name = "${var.short_name}-sec"
  description = "Allow inbound traffic to nodes"
  vpc_id = "${aws_vpc.main_network.id}"

  ingress { # SSH
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Mesos
    from_port = 5050
    to_port = 5050
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Marathon
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Chronos
    from_port = 4400
    to_port = 4400
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Consul
    from_port = 8500
    to_port = 8500
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # ICMP
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress { # SSH
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # HTTP
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # HTTPS
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
output "vpc_subnet" {
  value = "${aws_subnet.main_subnet.id}"
}

output "security_group" {
  value = "${aws_security_group.sec-groups.id}"
}

output "default_security_group" {
  value = "${aws_vpc.main_network.default_security_group_id}"
}

output "control_ids" {
  value = "${aws_instance.tflearn.id}"
}

output "control_ips" {
  value = "${aws_instance.tflearn.public_ip}"
}