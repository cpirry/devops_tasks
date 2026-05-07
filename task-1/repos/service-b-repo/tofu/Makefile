ENV     ?= dev
BACKEND = environments/backends/$(ENV).tf
VARS    = environments/vars/$(ENV).tfvars


init:
	tofu init \
		-backend-config=$(BACKEND)

plan:
	tofu plan \
		-var-file=$(VARS)

apply:
	tofu apply \
		-auto-approve \
		-var-file=$(VARS)

destroy:
	tofu destroy \
		-auto-approve \
		-var-file=$(VARS)

fmt:
	tofu fmt -recursive

validate:
	tofu validate

.PHONY: init plan apply destroy fmt validate