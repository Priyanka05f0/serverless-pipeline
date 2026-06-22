.PHONY: all dev staging prod clean init-all help

AWS_REGION := us-east-1
TF_STATE_BUCKET ?= your-tf-state-bucket
TF_LOCK_TABLE ?= your-tf-lock-table

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  dev       Deploy to dev environment"
	@echo "  staging   Deploy to staging environment"
	@echo "  prod      Deploy to prod environment (blue=current slot)"
	@echo "  clean     Destroy ALL environments (careful!)"
	@echo "  init-all  Init terraform for all environments"
	@echo ""
	@echo "Required env vars: TF_STATE_BUCKET, TF_LOCK_TABLE, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY"

all: dev staging prod

init-all:
	@echo "--- Initializing all environments ---"
	terraform -chdir=./terraform/environments/dev init \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="key=dev.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TF_LOCK_TABLE)"
	terraform -chdir=./terraform/environments/staging init \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="key=staging.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TF_LOCK_TABLE)"
	terraform -chdir=./terraform/environments/prod init \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="key=prod.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TF_LOCK_TABLE)"

dev:
	@echo "--- Deploying to DEV ---"
	terraform -chdir=./terraform/environments/dev init \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="key=dev.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TF_LOCK_TABLE)"
	terraform -chdir=./terraform/environments/dev plan \
		-var="environment_name=dev" \
		-var="region=$(AWS_REGION)" \
		-out=dev.tfplan
	terraform -chdir=./terraform/environments/dev apply -auto-approve dev.tfplan

staging:
	@echo "--- Deploying to STAGING ---"
	terraform -chdir=./terraform/environments/staging init \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="key=staging.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TF_LOCK_TABLE)"
	terraform -chdir=./terraform/environments/staging plan \
		-var="environment_name=staging" \
		-var="region=$(AWS_REGION)" \
		-out=staging.tfplan
	terraform -chdir=./terraform/environments/staging apply -auto-approve staging.tfplan

prod:
	@echo "--- Deploying to PROD (Blue/Green) ---"
	terraform -chdir=./terraform/environments/prod init \
		-backend-config="bucket=$(TF_STATE_BUCKET)" \
		-backend-config="key=prod.tfstate" \
		-backend-config="region=$(AWS_REGION)" \
		-backend-config="dynamodb_table=$(TF_LOCK_TABLE)"
	terraform -chdir=./terraform/environments/prod plan \
		-var="environment_name=prod" \
		-var="region=$(AWS_REGION)" \
		-var="active_slot=$(ACTIVE_SLOT)" \
		-out=prod.tfplan
	terraform -chdir=./terraform/environments/prod apply -auto-approve prod.tfplan

clean:
	@echo "--- Destroying ALL environments ---"
	@read -p "Are you sure? This will destroy everything! [y/N] " confirm && [ "$$confirm" = "y" ]
	terraform -chdir=./terraform/environments/dev destroy -auto-approve \
		-var="environment_name=dev" -var="region=$(AWS_REGION)"
	terraform -chdir=./terraform/environments/staging destroy -auto-approve \
		-var="environment_name=staging" -var="region=$(AWS_REGION)"
	terraform -chdir=./terraform/environments/prod destroy -auto-approve \
		-var="environment_name=prod" -var="region=$(AWS_REGION)" -var="active_slot=blue"
