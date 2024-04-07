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
### Code Build
##########################################################
resource "aws_codebuild_project" "build-project" {
  name                   = "build-project"
  service_role           = aws_iam_role.codebuild_role.arn
  build_timeout          = 60
  concurrent_build_limit = null

  artifacts {
    name      = "build-project"
    packaging = "NONE"
    type      = "CODEPIPELINE"
  }

  cache {
    modes = [
      "LOCAL_DOCKER_LAYER_CACHE",
      "LOCAL_SOURCE_CACHE",
      "LOCAL_CUSTOM_CACHE"
    ]
    type = "LOCAL"
  }

  source {
    type                = "CODEPIPELINE"                  # 이 예시에서는 소스가 없습니다. 필요에 따라 수정하세요.
    buildspec           = file("../deploy/buildspec.yml") # 빌드 스펙 파일의 경로를 지정하세요.
    report_build_status = false
    insecure_ssl        = false
    git_clone_depth     = 0
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"                            # 빌드 환경을 선택하세요.
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0" # arm64 아키텍처 이미지를 선택하세요.
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "CODEBUILD_CONFIG_AUTO_DISCOVER"
      type  = "PLAINTEXT"
      value = "true"
    }
  }

  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/aws/codebuild/codebuild-project"
      stream_name = "build"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }
}


#########################################################
## Code Pipeline 
#########################################################
resource "aws_codepipeline" "codepipeline" {
  depends_on = [aws_kms_key.s3kmskey, aws_codebuild_project.build-project]

  name          = "ecs-pipeline"
  role_arn      = aws_iam_role.codepipeline_role.arn
  pipeline_type = "V2"

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
        ProjectName = aws_codebuild_project.build-project.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      category = "Deploy"
      configuration = {
        "ApplicationName"     = "ecs-codedeploy"
        "DeploymentGroupName" = "ecs-dep-group"
      }
      input_artifacts = [
        "build_output",
      ]
      name             = "codeDeploy"
      output_artifacts = []
      owner            = "AWS"
      provider         = "CodeDeploy"
      region           = "ap-northeast-2"
      run_order        = 1
      version          = "1"
    }
  }
}
