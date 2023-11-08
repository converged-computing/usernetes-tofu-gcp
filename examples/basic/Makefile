.PHONY: all
all: init fmt validate deploy

.PHONY: init
init: 
	tofu init
	
.PHONY: fmt
fmt: 
	tofu fmt

.PHONY: validate
validate: 
	tofu validate
	
.PHONY: deploy
deploy: 
	export GOOGLE_PROJECT=$(gcloud config get-value core/project)
	tofu apply -var-file basic.tfvars -var region=us-central1 -var project_id=$(gcloud config get-value core/project) -var network_name=foundation-net -var zone=us-central1-a

.PHONY: destroy
destroy: 
	export GOOGLE_PROJECT=$(gcloud config get-value core/project)
	tofu destroy -var-file basic.tfvars -var region=us-central1 -var project_id=$(gcloud config get-value core/project) -var network_name=foundation-net -var zone=us-central1-a
