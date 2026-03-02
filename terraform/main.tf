terraform {
  backend "s3" {
    bucket = "sp-01102026-aws-kub"
    key    = "openshift-project/terraform.tfstate"
    region = "us-east-1"
    # No credentials here! We use OIDC/IRSA.
  }
}