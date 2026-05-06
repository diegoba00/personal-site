terraform {
  backend "s3" {
    bucket         = "dha-personal-site-tfstate"
    key            = "personal-site/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "dha-personal-site-tfstate-lock"
    encrypt        = true
  }
}
