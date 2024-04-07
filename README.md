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
```

- ECR (Register)
- ECS Cluster
- ECS Service
- ECS Task Definition
- Application Load Balancer
- Target Group
- Lister Rule