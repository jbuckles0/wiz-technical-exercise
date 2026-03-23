
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 MongoDB Backup Bucket
resource "aws_s3_bucket" "mongo_backup" {
  bucket        = "${var.project_name}-mongo-backup-${random_id.suffix.hex}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "${var.project_name}-mongo-backup" })
}

resource "aws_s3_bucket_public_access_block" "mongo_backup" {
  bucket = aws_s3_bucket.mongo_backup.id

  # WEAKNESS: Allowing public access
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# WEAKNESS: Allowing public read and list
resource "aws_s3_bucket_policy" "mongo_backup" {
  bucket     = aws_s3_bucket.mongo_backup.id
  depends_on = [aws_s3_bucket_public_access_block.mongo_backup]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadListAll"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.mongo_backup.arn,
          "${aws_s3_bucket.mongo_backup.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "mongo_backup" {
  bucket = aws_s3_bucket.mongo_backup.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"
    expiration {
      days = 30
    }
    filter {
      prefix = "backups/"
    }
  }
}
