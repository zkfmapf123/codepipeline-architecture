#####################################################################
## ECS Execute Role
#####################################################################
data "aws_iam_policy" "ecs_task_execution" {
  for_each = toset(["AmazonECSTaskExecutionRolePolicy", "AWSCodeDeployFullAccess", "AWSCodeDeployRoleForECS"])
  name     = each.value
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ecs_task_policy" {
  name = "ecs-execution-list"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:Describe*",
          "ecs:List*",
          "ecs:RunTask"
        ]
        Effect = "Allow"
        Resource = [
          "*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attach" {
  for_each = data.aws_iam_policy.ecs_task_execution

  role       = aws_iam_role.ecs_task_role.name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attach_2" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

#####################################################################
## ECS CodeDeploy Role
#####################################################################
data "aws_iam_policy" "ecs_codedeploy" {
  name = "AWSCodeDeployRole"
}

resource "aws_iam_role" "ecs_code_deploy" {
  name = "ecs-codedeploy-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codedeploy.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ecs-tasks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_code_deploy_list" {
  name = "ecs_code_deploy_list"
  path = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:Describe*",
        ]
        Effect = "Allow"
        Resource = [
          "*"
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_codedeploy_policy_attach_1" {

  role       = aws_iam_role.ecs_code_deploy.name
  policy_arn = data.aws_iam_policy.ecs_codedeploy.arn
}


resource "aws_iam_role_policy_attachment" "ecs_codedeploy_policy_attach_2" {

  role       = aws_iam_role.ecs_code_deploy.name
  policy_arn = aws_iam_policy.ecs_code_deploy_list.arn
}