terraform {
  backend "s3" {
    bucket         = "adnubes-tfstate-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "adnubes-tf-lock-table"
    kms_key_id     = "alias/adnubes-tfstate-key"
  }
}
