# Cloudflare R2(S3 호환)를 원격 state 저장소로 사용합니다.
# 계정별 endpoint와 access key는 코드에 두지 않고 `terraform init -backend-config=backend.hcl` 로 전달합니다.
# (backend.hcl.example 참고)
# 참고: R2에는 DynamoDB 같은 네이티브 state lock이 없습니다. 1인 운영이라 감수했고, 협업 시에는 별도 락이 필요합니다.
terraform {
  backend "s3" {
    bucket                      = "portfolio-web"
    key                         = "infra/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}
