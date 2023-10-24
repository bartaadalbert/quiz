# Message colors
_SUCCESS := "\033[32m[%s]\033[0m %s\n"
_DANGER := "\033[31m[%s]\033[0m %s\n"
_INFO := "\033[1;34m[%s]\033[0m %s\n"
_ATTAINTION := "\033[93m[%s]\033[0m %s\n"
#APP for test 
IMAGE_BUILDER := node:12-alpine

STATIC_DOCKERFILE := Dockerfile.stub
DOCKERFILE := Dockerfile

APP := $(shell basename -s .git $(shell git remote get-url origin 2>/dev/null || echo "defapp"))
GIT_PATH := $(shell git remote get-url origin | sed 's/.*github.com\//github.com\//;s/\.git$$//' || echo "github.com/yourname/yourrepo")
# Convert domething text to lowercase
to_lowercase = $(shell echo $(1) | tr A-Z a-z)

#Version get
# VERSION := v$(shell git describe --tags --abbrev=0 2>/dev/null || echo "-$(shell date +%s)")-$(shell git rev-parse --short HEAD)
VERSION := v$(shell git describe --tags --abbrev=0 2>/dev/null || echo "1.0.0")-$(shell git rev-parse --short HEAD)

# default OS typew
UNAME := $(shell uname -s 2>/dev/null || echo "linux")
OS ?= $(call to_lowercase,$(UNAME))

TARGETARCH := amd64
ARCH_SHORT_NAME := amd
APP_FULL_NAME := $(APP)

# OS types can be
SUPPORTED_OS = linux darwin windows
# Supported architecturees
SUPPORTED_ARCH := amd64 arm64


# Verify the OS type
ifeq ($(filter $(OS),$(SUPPORTED_OS)),)
$(error Invalid OS type $(OS). Supported OS types are: $(SUPPORTED_OS))
endif

#REGISTRY NAME
REGISTRY := ghcr.io/bartaadalbert

#IF using like this please check the Dockerfile.stub stuble settings!!! Also atantion for settings $ based variables in makefile
BUILDER_SETTINGS := COPY --from=builder /app/build /usr/share/nginx/html

BUILDER_LAST_ACTION := COPY ./dockerfiles/nginx/nginx.conf /etc/nginx/conf.d/default.conf

ENTRYPOINT := ENTRYPOINT [\"nginx\", \"-g\", \"daemon off;\"]

EXPOSE :=80

# APP_API_URL := https://api.url

# List of variables to display in help
VARIABLES_ARRAY := APP GIT_PATH VERSION  OS TARGETARCH IMAGE_BUILDER REGISTRY SUPPORTED_ARCH BUILDER_SETTINGS ENTRYPOINT STATIC_DOCKERFILE DOCKERFILE APP_API_URL

.PHONY: help
help: ##Help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf $(_DANGER) "Available variables and theur values:"
	@printf $(_INFO) "-----------START-----------"
	@$(foreach var,$(VARIABLES_ARRAY),printf $(_ATTAINTION) "$(var) = $($(var))";)
	@printf $(_INFO) "-----------END-----------"
	@printf $(_DANGER) "AND VARIABLES AND VALUES"

# Default target to print settings
.DEFAULT_GOAL := help

preconfig: ## Make Dockerfile from template it can be more powerful in future
	@if [ -f $(STATIC_DOCKERFILE) ]; then \
		cat $(STATIC_DOCKERFILE) > $(DOCKERFILE); \
		echo $(BUILDER_SETTINGS) >> $(DOCKERFILE); \
		echo $(BUILDER_LAST_ACTION) >> $(DOCKERFILE); \
	else \
        printf $(_DANGER) "$(STATIC_DOCKERFILE) does not exist"; \
    fi

test: ## Check test or kode errors
	@if ! npm run test -- --watchAll=false; then \
		printf $(_DANGER) "Tests failed,build stopp"; \
		exit 1; \
	fi
	@printf $(_SUCCESS) "Tests was passed, OK"
	@echo "\n"

build: ##Build the npm for OS type
	@printf $(_SUCCESS) "Builder for $(OS) architecture $(TARGETARCH)"
	@printf $(_ATTAINTION) "-----------START BUILD-----------"
	npm run build
	@printf $(_ATTAINTION) "-----------END BUILD-----------"
	@if [ $$? -ne 0 ]; then \
        printf $(_DANGER) "Error: Failed to build $(APP_FULL_NAME) for $(OS)"; \
        exit 1; \
    fi
	@printf $(_SUCCESS) "Successfully built $(APP_FULL_NAME) for $(OS) with architecture $(TARGETARCH)\n"
	@make test

image: preconfig ## Default image maker for linux or you need call with makefile variables!!!
	@docker build \
	--no-cache \
	-t $(REGISTRY)/$(APP):$(VERSION) \
	-f $(DOCKERFILE) \
	--build-arg APP_NAME=$(APP) \
	--build-arg FROM_IMAGE=$(IMAGE_BUILDER) \
	--build-arg APP_API_URL=$(APP_API_URL) \
	.

#aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 926813703698.dkr.ecr.eu-central-1.amazonaws.com
push: ## Push the Docker image for the specified OS type
	@printf $(_INFO) "Start pushing your docker image with registry and nameversion: $(REGISTRY)/$(APP):$(VERSION) !\n"
	@docker push $(REGISTRY)/$(APP):$(VERSION)
	@printf $(_SUCCESS) "Your image was Successfully pushed!\n"
	
save: ## Save Docker image to a tar file
	@docker images
	@read -p "Enter the name of the Docker image to save: " IMAGE_NAME; \
	read -p "Enter the path to save the Docker image: " IMAGE_PATH; \
	if [ -f "$$IMAGE_PATH/$$IMAGE_NAME.tar" ]; then \
        printf $(_WARNING) "The image file already exists. Do you want to overwrite it? [y/n]: "; \
        read OVERWRITE; \
        if [ $$OVERWRITE != "y" ]; then \
            printf $(_INFO) "The image file was not saved."; \
            exit 0; \
        fi; \
    fi; \
	docker save -o $$IMAGE_PATH/$$IMAGE_NAME.tar $$IMAGE_NAME; \
	printf $(_SUCCESS) "The Docker image was saved to $$IMAGE_PATH/$$IMAGE_NAME.tar."


clean:## Clean all targets and images
	@rm -f build node_modules package-lock.json
	@docker images --filter=reference=$(REGISTRY)/$(APP) -q | xargs -r docker rmi -f || true; \