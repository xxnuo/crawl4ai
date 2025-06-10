VERSION := $(shell git rev-parse --short HEAD)
UV := ~/.local/bin/uv
CURL := $(shell if command -v axel >/dev/null 2>&1; then echo "axel"; else echo "curl"; fi)
REMOTE := nvidia@gpu
REMOTE_PATH := ~/work/lzc-crawl4ai
DOCKER_REGISTRY := registry.lazycat.cloud/x/lzc-crawl4ai
DOCKER_NAME := lzc-crawl4ai
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
        --build-arg "HTTP_PROXY=$(ENV_PROXY)" \
        --build-arg "HTTPS_PROXY=$(ENV_PROXY)" \
		--build-arg "ALL_PROXY=$(ENV_PROXY)" \
        --build-arg "NO_PROXY=localhost,192.168.1.200,registry.lazycat.cloud" \
		--build-arg "TARGETARCH=arm64" \
		--build-arg "USE_LOCAL=true" \
		."

test: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm \
		--name $(DOCKER_NAME) \
		--network host \
		$(DOCKER_REGISTRY):latest"

test-local:
	docker run -it --rm \
		--name $(DOCKER_NAME) \
		-p 3002:3000 \
		$(DOCKER_REGISTRY):latest

inspect:
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker run -it --rm \
		--name $(DOCKER_NAME) \
		--network host \
		$(DOCKER_REGISTRY):latest \
		bash"

push: build
	ssh -t $(REMOTE) "cd $(REMOTE_PATH) && \
		docker push $(DOCKER_REGISTRY):$(VERSION) && \
		docker push $(DOCKER_REGISTRY):latest"

.PHONY: compile build test inspect push sync-from-gpu sync-to-gpu sync-clean