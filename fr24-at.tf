# Specify the provider and access details
provider "aws" {
  region                  = "eu-west-2"
  access_key = "xxxxxxxxxxxxxxxx"
  secret_key = "xxxxxxxxxxxxxxxxxx"

}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "sg_elb" {
  name        = "sg_elb"
  description = "Used for elb"
  vpc_id      = "${aws_vpc.default.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for SSH and HTTP
resource "aws_security_group" "sg_nginx" {
  name        = "sg_nginx"
  description = "Used for instances"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_acm_certificate" "webexamplecom" {
  private_key      = file("/Users/kapilvihan/assignment/nginx/web.example.com-key.pem")
  certificate_body = file("/Users/kapilvihan/assignment/nginx/web.example.com-cert.pem")
}

resource "aws_elb" "elb_web" {
  name = "elb-nginx"

  subnets         = ["${aws_subnet.default.id}"]
  security_groups = ["${aws_security_group.sg_elb.id}"]
  instances       = "${aws_instance.nginx.*.id}"

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  listener {
    instance_port     = 443
    instance_protocol = "https"
    lb_port           = 443
    lb_protocol       = "https"
    ssl_certificate_id = "${aws_acm_certificate.webexamplecom.id}"
  }
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "assignment-key"
  public_key = file("/Users/kapilvihan/assignment/nginx/assignment_private-key.pub")
}

resource "aws_instance" "nginx" {
  count = 3
   ami             = "ami-0a0cb6c7bcb2e4c51" # id of desired AMI in eu-west-2
instance_type   = "t2.micro"

  # SSH keypair.
  key_name = "${aws_key_pair.ssh-key.id}"

  # Allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.sg_nginx.id}"]

  # Assign same subnet as where our ELB resides. 
    subnet_id = "${aws_subnet.default.id}"

}

data "template_file" "nginx_hosts" {
  template = file("./nginx_hosts.cfg")
  depends_on = [aws_instance.nginx]
  vars = {
    api_public = "${join("\n",aws_instance.nginx.*.public_ip)}"
    api_internal = "${join("\n",aws_instance.nginx.*.private_ip)}"
  }
}

resource "local_file" "nginx_file" {
  content  = "${data.template_file.nginx_hosts.rendered}"
  filename = "./nginx2-host"
}

resource "null_resource" "runansible" {
depends_on = [local_file.nginx_file]
provisioner "local-exec" {
     command = "ansible-playbook -u ec2-user -i /Users/kapilvihan/assignment/nginx/nginx2-host --private-key /Users/kapilvihan/assignment/nginx/assignment_private-key -u ec2-user nginx-install.yml"
}
}

output "elb_url" {
  value = aws_elb.elb_web.dns_name
}
