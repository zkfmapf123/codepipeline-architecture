plan:
	cd infra && terraform plan 

apply:
	cd infra && terraform apply --auto-approve

## buildpsec update
spec-update:
	cd infra && terraform apply -target=aws_codebuild_project.build-project --auto-approve

push-master:
	git add . && git commit -m "fix" && git push origin master