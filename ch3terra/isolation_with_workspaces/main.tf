provider "aws" {
  region = "eu-central-1"

}
terraform {
  backend "s3" {
    bucket         = "terraform-state-loc"
    key            = "workspaces-example/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "tf-state-lock"
    encrypt        = true

  }
}

resource "aws_instance" "example" {
  instance_type = terraform.workspace == "default" ? "t2.medium" : "t2.micro"
  ami           = "ami-023adaba598e661ac"
}