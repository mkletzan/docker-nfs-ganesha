.PHONY: build build-multiarch test test-verbose test-multiarch clean install-build-deps install-test-deps

IMAGE_NAME ?= nfs-ganesha
IMAGE_TAG ?= latest

# Detect host architecture
HOST_ARCH := $(shell uname -m)
DOCKER_ARCH := $(shell echo $(HOST_ARCH) | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')

# Architecture to test (defaults to host architecture)
ARCH ?= $(DOCKER_ARCH)

# All supported architectures (s390x excluded - no nfs-ganesha-6 packages available)
ALL_ARCHS := linux/amd64,linux/arm64

# Detect docker compose command (plugin vs standalone)
DOCKER_COMPOSE := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# Check build dependencies (no sudo - just reports what's missing)
install-build-deps:
	@echo "Checking build dependencies..."
	@MISSING=""; \
	if ! command -v docker >/dev/null 2>&1; then \
		echo "❌ Docker is not installed"; \
		MISSING="$$MISSING docker"; \
	else \
		echo "✓ Docker is installed"; \
		if ! docker ps >/dev/null 2>&1; then \
			echo "⚠️  Docker is installed but not running or requires permissions"; \
			echo "   Run: sudo systemctl start docker"; \
			echo "   Add user to docker group: sudo usermod -aG docker $(USER)"; \
		fi; \
	fi; \
	if [ -n "$$MISSING" ]; then \
		echo ""; \
		echo "Missing dependencies:$$MISSING"; \
		echo ""; \
		echo "To install on Fedora/RHEL/CentOS:"; \
		echo "  sudo dnf install -y$$MISSING"; \
		echo "  sudo systemctl enable --now docker"; \
		echo "  sudo usermod -aG docker $(USER)"; \
		echo "  # Log out and back in for group changes to take effect"; \
		exit 1; \
	fi

# Check test dependencies (no sudo - just reports what's missing)
install-test-deps: install-build-deps
	@echo "Checking test dependencies..."
	@MISSING=""; \
	if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then \
		echo "❌ docker-compose is not installed"; \
		MISSING="$$MISSING docker-compose"; \
	else \
		echo "✓ docker-compose is installed"; \
	fi; \
	if [ -n "$$MISSING" ]; then \
		echo ""; \
		echo "Missing dependencies:$$MISSING"; \
		echo ""; \
		echo "To install on Fedora/RHEL/CentOS:"; \
		echo "  sudo dnf install -y$$MISSING"; \
		exit 1; \
	fi

build:
	@if [ "$(ARCH)" != "$(DOCKER_ARCH)" ]; then \
		echo "Building for $(ARCH) (host is $(DOCKER_ARCH), using QEMU emulation)..."; \
		docker buildx build --platform linux/$(ARCH) --load -t $(IMAGE_NAME):$(IMAGE_TAG) .; \
	else \
		echo "Building for $(ARCH) (native)..."; \
		docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .; \
	fi

build-multiarch:
	@echo "Building for all architectures: $(ALL_ARCHS)..."
	@docker buildx build --platform $(ALL_ARCHS) -t $(IMAGE_NAME):$(IMAGE_TAG) .

test: build
	@echo "Running tests..."
	@$(DOCKER_COMPOSE) -f tests/docker-compose.test.yml up -d --build >/dev/null 2>&1
	@$(DOCKER_COMPOSE) -f tests/docker-compose.test.yml logs -f test-runner
	@CONTAINER_ID=$$($(DOCKER_COMPOSE) -f tests/docker-compose.test.yml ps -aq test-runner); \
	EXIT_CODE=$$(docker inspect -f '{{.State.ExitCode}}' $$CONTAINER_ID 2>/dev/null || echo 1); \
	$(DOCKER_COMPOSE) -f tests/docker-compose.test.yml down -v >/dev/null 2>&1; \
	exit $$EXIT_CODE

test-verbose: build
	$(DOCKER_COMPOSE) -f tests/docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from test-runner
	$(DOCKER_COMPOSE) -f tests/docker-compose.test.yml down -v

test-multiarch:
	@echo "Testing all architectures: amd64, arm64"
	@echo "This may take 15-20 minutes due to QEMU emulation..."
	@echo ""
	@echo "=== Testing amd64 ==="
	@ARCH=amd64 $(MAKE) test || (echo "❌ amd64 tests failed"; exit 1)
	@echo ""
	@echo "=== Testing arm64 ==="
	@ARCH=arm64 $(MAKE) test || (echo "❌ arm64 tests failed"; exit 1)
	@echo ""
	@echo "✅ All architectures passed!"

# Clean up all Docker resources related to this project
clean:
	@echo "Cleaning up Docker resources for $(IMAGE_NAME)..."
	@echo "→ Stopping and removing test containers and volumes..."
	@$(DOCKER_COMPOSE) -f tests/docker-compose.test.yml down -v 2>/dev/null || true
	@echo "→ Removing Docker images..."
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@docker rmi tests-nfs-ganesha 2>/dev/null || true
	@echo "→ Removing stopped containers from this project..."
	@docker ps -a --filter "ancestor=$(IMAGE_NAME):$(IMAGE_TAG)" --format "{{.ID}}" | xargs -r docker rm 2>/dev/null || true
	@docker ps -a --filter "ancestor=tests-nfs-ganesha" --format "{{.ID}}" | xargs -r docker rm 2>/dev/null || true
	@echo "→ Pruning dangling images from builds..."
	@docker image prune -f --filter "label=maintainer=mkletzan@redhat.com" 2>/dev/null || true
	@echo "✓ Cleanup complete"
