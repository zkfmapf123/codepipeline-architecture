resource "aws_codedeploy_app" "code-deploy-app" {

  compute_platform = "ECS"
  name             = "ecs-codedeploy"
}

resource "aws_codedeploy_deployment_group" "ecs-codedeploy-group" {

  app_name               = aws_codedeploy_app.code-deploy-app.name
  deployment_group_name  = "ecs-dep-group"
  deployment_config_name = "ecs-dep-config"
  service_role_arn       = aws_iam_role.ecs_code_deploy.arn

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.ecs_cluster.name
    service_name = aws_ecs_service.ecs_service.name
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [
          aws_lb_listener.ecs_80.arn
        ]
      }

      ## blue
      target_group {
        name = aws_lb_target_group.ecs_tg_blue.name
      }

      ## green
      target_group {
        name = aws_lb_target_group.ecs_tg_green.name
      }
    }
  }



}
