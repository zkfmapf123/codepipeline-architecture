##########################################################
### S3 (Artifacts)
##########################################################
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "dd-codepipeline-bucket"
}

resource "aws_s3_bucket_public_access_block" "codepipeline_bucket_pab" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

##########################################################
### CodeStart Connection 
##########################################################
resource "aws_codestarconnections_connection" "git_connection" {
  name          = "github-connection"
  provider_type = "GitHub"
}

##########################################################
### KMS
##########################################################
resource "aws_kms_key" "s3kmskey" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 10
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Id" : "key-consolepolicy-3",
      "Statement" : [
        {
          "Sid" : "Enable IAM User Permissions",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "*"
          },
          "Action" : "kms:*",
          "Resource" : "*"
        }
      ]
  })
}

resource "aws_kms_alias" "s3kmskey_alias" {
  name          = "alias/s3kmskey"
  target_key_id = aws_kms_key.s3kmskey.key_id
}

##########################################################
### Code Pipeline 
##########################################################
resource "aws_codepipeline" "codepipeline" {
  depends_on = [aws_kms_key.s3kmskey]

  name     = "ecs-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_alias.s3kmskey_alias.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.git_connection.arn
        FullRepositoryId = "zkfmapf123/codepipeline-architecture"
        BranchName       = "master"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = "deploy"
        Environment = {
          "type" : "LINUX_CONTAINER"
          "image"       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
          "computeType" = "BUILD_GENERAL1_SMALL"
        }
      }
    }
  }
}
