# CodePipeline Architecture

![1](./public/1.png)

## Folder Architecture

```sh

    |- infra        ## infra use Terraform 
    |- server       ## server side application (express)
    |- deploy       ## deploy files (task-definition.json, appspec.yml)
```

## CodePipeline 구축 Terraform 

```sh
    ## 일부러 state는 설정안함 
    cd infra 
    terraform init && terraform apply
```

## 1. VPC 구축 및 ECS 설정

### VPC 

```sh
    ## Reference Terraform files
    infra/vpc.tf
```

- <a href="https://registry.terraform.io/modules/zkfmapf123/vpc3tier/lee/latest"> 모듈참조 </a>

### ECS Fargate 

```sh
    ## server 
    server/index.js

    ## Referenec Terraform files
    infra/ecs-alb.tf
    infra/ecs-iam.tf                ## ecs-execution-role, ecs-code-deploy-role
    infra/ecs-fargate.tf
    infra/ecs-code-deploy.tf
```

- ECR (Register)
- ECS Cluster
- ECS Service
- ECS Task Definition
- Application Load Balancer
- Target Group
- Lister Rule

- 참고사항

    - ECS Taks Definition의 경우 <a href="https://hub.docker.com/repository/docker/zkfmapf123/healthcheck/general"> zkfmapf123/healthcheck</a> Image를 사용합니다.
    - 이미지의 자세한 내용은 docker inspect 를 활용합니다
    - 처음 Provisioning 에만 사용됩니다.
    - 추후 배포는 CodePipeline + TaskDefinition 으로 구성합니다.
    - CodeDeploy를 사용하기 위해선 2가지 조건이 필요합니다. (Target Group : Blue/Green), (ECSService : BlueGreen Option)
    - 기존 ECS (Rolling) 배포옵션을 사용하고 있었다면, ECS Service를 재생성해야 합니다.
    - ECS CodeDeploy를 활용하기 위해선 2가지 파일이 필요합니다. (task-definition.json, appspec.yml)
    - CodeDeploy 배포옵션은 aws_codedeploy_deployment_group.*.deployment_config_name 옵션에서 수정합니다.

| 배포옵션                            | 설명                                                                                          |
|------------------------------------|------------------------------------------------------------------------------------------------|
| CodeDeployDefault.ECSAllAtOnce     | 모든 새 버전을 동시에 배포하고 이전 버전과 교체합니다.                                        |
| CodeDeployDefault.ECSCanary10Percent10Minutes | 새 버전을 Canary 배포로 배포하고, 각 배포 단계마다 최대 10%의 용량을 사용하여 교체합니다. |
| CodeDeployDefault.ECSCanary10Percent5Minutes  | Canary 배포로 새 버전을 배포하고, 각 배포 단계마다 최대 10%의 용량을 사용하여 교체합니다. |
| CodeDeployDefault.ECSCanary10Percent3Minutes  | Canary 배포로 새 버전을 배포하고, 각 배포 단계마다 최대 10%의 용량을 사용하여 교체합니다. |
| CodeDeployDefault.ECSTrafficShift   | 이전 버전과 새 버전 간의 트래픽을 제어하여 점진적으로 새 버전으로 전환합니다.                |

## 2. CodePipeline 구성

```sh

    ## Reference Terraform files
    infra/code-pipeline.tf
    infra/ecs-iam.tf

    ## buildspec 업데이트
    make spec-update
```

![2](./public/2.png)
![3](./public/3.png)
![4](./public/4.png)

- 참고사항
    - GitHub Connect은 연결하여야 한다
    - CodePipelin.Build 테라폼 빡세다
    - deploy 폴더안에 task_definition.json, AppSpec.yml 을 위치해야 Build Artifacts를 통해서 CodeDeploy가 배포됨
    - <b>BuildArtifacts에 구성파일만 존재하면 CodeDeploy는 쉽게 진행됨</b>
    - CodeDeploy가 아닌 ECS (Blue/Green) 으로 구성해야 함 (in CodePipeline)
    - 폴더지정 제대로 하자 에러 많이 남

    ```yml
    ...
    post_build:
    commands:
      - cd ..
      - ls -lah ./deploy

    artifacts:
        files:
        - "deploy/*"
    ```

## 3. 주의사항

- appspec.yml, taskdef.json 파일의 세부 Parameter를 꼼꼼하게 작성해야 함 (에러남)
- appspec.yml의 taskArn의 경우 현재 Family Revision + 1로 작성해야 에러가 안난다
- Policy 정리를 잘해야 한다 (현재는 최대한 열어놓은 상태임)

## 귀찮아서 안한거..

- Terraform은 Resource / Service 별로 폴더별로 관리해야 함
- Terraform Cloud를 붙힌다면 더더욱 좋을듯 함
- IAM Policy의 Resource는 개별로 지정하는 것이 좋음
- Task Definition, AppSpec 내의 Docker versioning은 추후에 진행해보자...
- Terrform이 다 구성되고, task_definition, AppSpec 을 자동으로 만들어주게끔 중간에 CLI를 만들어보는것도 좋을듯
- <b>CodeGuru Service가 Seoul Region에 들어오면 Security Scanning, Reviewer 구성해볼 예정</b>
- 운동해야되서 AWS Chatbot은 못붙힘 (쉬움)

## 이슈모음

### CodeDeployToECS (Revision Number Issue)

```sh
Deployment d-X1IRUVC7H외부 링크 failed. Error code: ECS_UPDATE_ERROR; Error message: The ECS service cannot be updated due to an unexpected error: Invalid revision number. Number: latest (Service: AmazonECS; Status Code: 400; Error Code: InvalidParameterException; Request ID: 380efecf-408c-43bb-9aaf-908912e8059a; Proxy: null). Check your ECS service status
```

- ECS Service 업데이트 시, Image가 잘못되어있었음
- ECR Registry 의 주소를 제대로 적어주자
- 그리고 latest가 아닌 VERSION을 명시해야 함

### CodeDeployToECS (Folder Path Issue)

```sh
An AppSpec file is required, but could not be found in the revision
```
- taskdef.json, appspec.yml 파일의 Path가 틀렸음
- buildoutputs 의 Path를 수정해줘야 함

### CodeDeployToECS (Task Definition)

```
The ECS service cannot be updated due to an unexpected error: TaskDefinition is inactive
```

- Service가 실행하는 Task와 CodeDeploy가 실행하는 Task의 값이 달라서 발생하는 문제
- AppSpec.yml 파일에 TaskDefinition을 올바르게 수정하자
- TaskDefinition의 Revision을 가공해서 sed 명령어로 수정
- 그 과정에서 "ecs:DescribeTaskDefinition" Policy가 추가됨
- <b>TaskDefinition.json에 ExecutionRole도 추가해야함 (위치중요) </b>

```yml
post_build:
    commands:
      - cd ..
      - REVISON=$(aws ecs describe-task-definition --task-definition arn:aws:ecs:ap-northeast-2:182024812696:task-definition/test-service-container-family | jq -r '.taskDefinition.revision')
      - REVISON=$((REVISON + 1)) ## 개정을 하나 올려줌...
      - echo "REVISION >> $REVISON"
      - sed -i 's/${REVISON}/'"$REVISON"'/g' deploy/appspec.yml
      - cat ./deploy/appspec.yml
      - ls -lah ./deploy
```

### CodeDeployToECS (TaskExecutionRole)

- taskexecutionRole의 정책이 부족함
- 몇가지 더 채워넣음

```
resource "aws_iam_policy" "ecs_task_policy" {
  name = "ecs-execution-list"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:Describe*",
          "ecs:List*",
          "ecs:RunTask",
          "ecs:StopTask",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:CreateLogGroup", ## Log Group...
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Effect = "Allow"
        Resource = [
          "*"
        ]
      },
      {
        "Effect" : "Allow",
        "Resource" : "*",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
      }
    ]
  })
}
```


## Reference

- <a href="https://repost.aws/questions/QU6quBySm3Tmqv1UixHTVRZw/listener-requirements-for-codedeploy-blue-green-deployments"> Blue/Green Target Group Issue </a>
