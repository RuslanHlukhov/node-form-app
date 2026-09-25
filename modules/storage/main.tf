resource "aws_s3_bucket" "app_images" {
  bucket_prefix = "node-app-images-"
  force_destroy = true
}