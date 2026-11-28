terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "state123partho"
    key          = "terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}