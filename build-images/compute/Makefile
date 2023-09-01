.PHONY: all
all: init fmt validate build

.PHONY: init
init: 
	packer init .
	
.PHONY: fmt
fmt: 
	packer fmt .

.PHONY: validate
validate: 
	packer validate .
	
.PHONY: build
build: 
	packer build -var machine_architecture="x86-64" -var project_id=${GOOGLE_PROJECT} compute.pkr.hcl
