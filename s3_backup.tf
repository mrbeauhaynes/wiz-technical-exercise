resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Publicly Readable S3 Storage Bucket for DB Backups
resource "aws_s3_bucket" "db_backups" {
  bucket        = "wiz-exercise-backups-${random_id.bucket_suffix.hex}"
  force_destroy = true

  tags = {
    Name        = "Public DB Backups"
    Environment = var.environment
  }
}

# Explicitly disable S3 Block Public Access
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.db_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Policy Granting Public Read (GetObject) and Public Listing (ListBucket)
resource "aws_s3_bucket_policy" "public_read_policy" {
  bucket = aws_s3_bucket.db_backups.id
  depends_on = [aws_s3_bucket_public_access_block.public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadAndList"
        Effect    = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.db_backups.arn,
          "${aws_s3_bucket.db_backups.arn}/*"
        ]
      }
    ]
  })
}