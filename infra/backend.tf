terraform {
  backend "s3" {
    bucket         = "adnubes-tfstate-bucket-us-east-2"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "adnubes-tf-lock-table-us-east-2"
    kms_key_id     = "alias/adnubes-tfstate-key-us-east-2"
  }
}
