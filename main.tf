provider "aws" {
  region = "eu-north-1"
}

data "template_file" "init" {
  template = file("install_webserver.sh")
  vars = {
    html_content = file("index.html")
    css_content  = file("style.css")
    js_content   = file("script.js")
  }
}

resource "aws_instance" "web_server" {
  ami           = "ami-075449515af5df0d1"
  instance_type = "t3.micro"
  key_name      = "mariamhostspace"
  security_groups = [aws_security_group.web_sg.name]

  user_data = base64encode(data.template_file.init.rendered)

  tags = {
    Name = "Altschool-Web-Server-Project"
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP, HTTPS and SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "web_eip" {
  instance = aws_instance.web_server.id
  domain   = "vpc"
}

output "public_ip" {
  value = aws_eip.web_eip.public_ip
  description = "Public IP of the web server"
}
