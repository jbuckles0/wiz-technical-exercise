# ECR Container Registry for Tasky app
resource "aws_ecr_repository" "tasky" {
  name                 = "tasky"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = "tasky" })
}

resource "aws_ecr_lifecycle_policy" "tasky" {
  repository = aws_ecr_repository.tasky.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
