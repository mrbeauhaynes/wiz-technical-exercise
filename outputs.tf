output "mongodb_private_ip" {
  description = "Private IP of MongoDB EC2 instance for application connection"
  value       = aws_instance.mongodb.private_ip
}

output "mongodb_public_ip" {
  description = "Public IP of MongoDB EC2 instance (Exposed SSH)"
  value       = aws_instance.mongodb.public_ip
}

output "s3_backup_bucket_url" {
  description = "Public S3 Backup Bucket"
  value       = "http://${aws_s3_bucket.db_backups.bucket}.s3.amazonaws.com"
}

output "eks_cluster_name" {
  description = "Name of the deployed private EKS cluster"
  value       = aws_eks_cluster.main.name
}