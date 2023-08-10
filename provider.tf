provider "aws" {
  region  = var.aws_region
  profile = "dev"

  default_tags {
    tags = {
      Created    = "terraform"
      Repository = var.service_name
    }
  }
}
