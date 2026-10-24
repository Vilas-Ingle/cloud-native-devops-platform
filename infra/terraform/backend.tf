terraform {
  backend "s3" {
    bucket = "cloud-native-devops-terraform-state-vilas"
    key    = "cloud-native-devops/terraform.tfstate"
    region = "ap-south-1"
  }
}