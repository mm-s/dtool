setup:
	terraform init

provision:
	terraform plan
	terraform apply -auto-approve

info:
	terraform output

destroy:
	terraform destroy -auto-approve

.PHONY: provision info destroy setup
