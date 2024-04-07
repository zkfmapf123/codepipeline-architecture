plan:
	cd infra && terraform plan 

apply:
	cd infra && terraform apply --auto-approve

## buildpsec update
spec-update:
	cd infra && terraform apply -target=aws_codebuild_project.build-project --auto-approve
