output "mongo_vm_public_ip" {
  description = "Public IP of the MongoDB VM (SSH and demo access)"
  value       = aws_instance.mongo_vm.public_ip
}

output "mongo_vm_private_ip" {
  description = "Private IP for MONGODB_URI in Kubernetes secret"
  value       = aws_instance.mongo_vm.private_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker push"
  value       = aws_ecr_repository.tasky.repository_url
}

output "eks_cluster_name" {
  description = "EKS cluster name for kubectl config"
  value       = module.eks.cluster_name
}

output "backup_bucket_name" {
  description = "S3 bucket for MongoDB backups (intentionally public)"
  value       = aws_s3_bucket.mongo_backup.bucket
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID for console demo"
  value       = aws_guardduty_detector.main.id
}
