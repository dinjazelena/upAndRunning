provider "aws" {
  region = "eu-central-1"

}

terraform {
  backend "s3" {
    bucket         = "terraform-state-loc"
    key            = "stage/data-stores/mysql/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "tf-state-lock"
    encrypt        = true

  }
}
resource "aws_db_instance" "example" {
  identifier_prefix   = "terra-up-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true
  db_name             = "example_database"
  username            = var.db_username
  password            = var.db_password
}