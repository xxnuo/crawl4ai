VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/work/crawl4ai
DOCKER_REGISTRY := registry.lazycat.cloud/x/crawl4ai
DOCKER_NAME := crawl4ai
ENV_PROXY := http://192.168.1.200:7890

sync-from-gpu:
	rsync -arvzlt --delete --exclude-from=.rsyncignore $(REMOTE):$(REMOTE_PATH)/ ./

sync-to-gpu:
	ssh -t $(REMOTE) "mkdir -p $(REMOTE_PATH)"
	rsync -arvzlt --delete --exclude-from=.rsyncignore ./ $(REMOTE):$(REMOTE_PATH)

sync-clean:
	ssh -t $(REMOTE) "rm -rf $(REMOTE_PATH)"

build: sync-to-gpu
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker build \
	    -f Dockerfile \
	    -t $(DOCKER_REGISTRY):$(VERSION) \
	    -t $(DOCKER_REGISTRY):latest \
        --network host \
		--build-arg INSTALL_TYPE=default \
  		--build-arg ENABLE_GPU=false \
		--build-arg TARGETARCH=arm64 \
        --build-arg "HTTP_PROXY=$(ENV_PROXY)" \
        --build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		."

test: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all --shm-size=1g --name $(DOCKER_NAME) --network host -v ./output:/app/output $(DOCKER_REGISTRY):$(VERSION)"

inspect: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm --gpus all --shm-size=1g --name $(DOCKER_NAME) --network host -v ./output:/app/output $(DOCKER_REGISTRY):$(VERSION) bash"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY):$(VERSION) && \
		docker push $(DOCKER_REGISTRY):latest"

build-amd:
	docker build \
	    -f Dockerfile \
	    -t $(DOCKER_REGISTRY)-amd:$(VERSION) \
	    -t $(DOCKER_REGISTRY)-amd:latest \
        --network host \
		--build-arg INSTALL_TYPE=default \
  		--build-arg ENABLE_GPU=false \
		--build-arg TARGETARCH=amd64 \
        --build-arg "HTTP_PROXY=$(ENV_PROXY)" \
        --build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		.

test-amd: build-amd
	docker run -it --rm --gpus all --shm-size=1g --name $(DOCKER_NAME) --network host -v ./output:/app/output $(DOCKER_REGISTRY)-amd:$(VERSION)

inspect-amd: build-amd
	docker run -it --rm --gpus all --shm-size=1g --name $(DOCKER_NAME) --network host -v ./output:/app/output $(DOCKER_REGISTRY)-amd:$(VERSION) bash

push-amd: build-amd
	docker push $(DOCKER_REGISTRY)-amd:$(VERSION) && \
	docker push $(DOCKER_REGISTRY)-amd:latest

.PHONY: build test inspect push build-amd test-amd inspect-amd push-amd