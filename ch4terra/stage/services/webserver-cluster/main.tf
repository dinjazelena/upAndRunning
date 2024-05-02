provider "aws" {
  region = "eu-central-1"
}

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  cluster_name           = "wevservers-stage"
  db_remote_state_bucket = "terraform-state-loc"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"
  instance_type          = "t2.micro"
  min_size               = 2
  max_size               = 2
}

output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}