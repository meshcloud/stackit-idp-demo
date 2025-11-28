terraform {
  backend "s3" {
    bucket = "meshstack"
    key    = "terraform/bootstrap/configure/terraform.tfstate"
    region = "eu01"

    endpoint                    = "https://object.storage.eu01.onstackit.cloud"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
