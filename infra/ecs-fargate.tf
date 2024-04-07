#############################################################################
## ECR Registry
#############################################################################
resource "aws_ecr_repository" "ecr_repository" {
  name = "ecr_repository"

  tags = {
    Name = "ecr_repository"
  }
}

#############################################################################
## ECS Cluster
#############################################################################
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs_cluster"
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# #############################################################################
# ## ECS TaskDefinition
# 처음 Terraform을 사용할때는 다른 이미지를 사용해서 Provisioing을 진행합니다.
# 추후 CD 배포는 CodePipeline으로 진행하기 때문에 Lifecycle 옵션을 사용해서 무시합니다
# #############################################################################
resource "aws_ecs_task_definition" "ecs_task" {
  family = "ecs-task"
  container_definitions = jsonencode([
    {
      name      = "ecs-task-container"
      image     = "zkfmapf123/healthcheck:latest"
      cpu       = 256
      memory    = 512
      essential = true,
      environments = [
        {
          name  = "PORT",
          value = "3000"
        }
      ],
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group : "ecs-task-container"
          awslogs-create-group : "true"
          awslogs-region : "ap-northeast-2"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  network_mode             = "awsvpc" ## Only FARGATE
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_role.arn

  lifecycle {
    ignore_changes = [container_definitions]
  }
}

# #############################################################################
# ## ECS Service
# #############################################################################
resource "aws_security_group" "ecs_sg" {
  name        = "ecs_sg"
  description = "ecs to sg"
  vpc_id      = module.codepipeline-vpc.vpc.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs_sg"
  }
}

resource "aws_ecs_service" "ecs_service" {
  name                   = "test-service-container"
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.ecs_task.arn
  desired_count          = 1
  iam_role               = aws_iam_role.ecs_task_role.arn
  depends_on             = [aws_iam_role.ecs_task_role]
  enable_execute_command = true

  network_configuration {
    assign_public_ip = false
    subnets          = values(module.codepipeline-vpc.vpc.db_subnets)
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  force_new_deployment = false
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tg_green.arn
    container_name   = "test-service-container"
    container_port   = "3000"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      task_definition
    ]
  }
}



