provider "aws" {
  region = "eu-central-1"
}


resource "aws_instance" "example" {
  ami           = "ami-023adaba598e661ac"
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  user_data_replace_on_change = true

  vpc_security_group_ids = [ aws_security_group.instance.id ]

  tags = {
    Name = "HelloTerraform"
  }
}

# This security groups allows incoming requests on port 8080 from any IP(cicdr_blocks)

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


}