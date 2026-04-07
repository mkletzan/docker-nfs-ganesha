.PHONY: build test test-verbose clean install-build-deps install-test-deps

IMAGE_NAME ?= nfs-ganesha
IMAGE_TAG ?= latest

# Install build dependencies
install-build-deps:
	@echo "Checking build dependencies..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Installing Docker..."; \
		sudo dnf install -y docker; \
		sudo systemctl enable --now docker; \
		sudo usermod -aG docker $(USER); \
		echo "⚠️  Docker installed. You may need to log out and back in for group changes to take effect."; \
	else \
		echo "✓ Docker is already installed"; \
	fi

# Install test dependencies
install-test-deps: install-build-deps
	@echo "Checking test dependencies..."
	@if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then \
		echo "Installing docker-compose..."; \
		if sudo dnf install -y docker-compose; then \
			echo "✓ docker-compose installed"; \
		else \
			echo "❌ Failed to install docker-compose"; \
			echo "Please run manually: sudo dnf install -y docker-compose"; \
			exit 1; \
		fi \
	else \
		echo "✓ docker-compose is already installed"; \
	fi

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

test: build
	@echo "Running tests..."
	@docker-compose -f tests/docker-compose.test.yml up -d --build >/dev/null 2>&1
	@docker-compose -f tests/docker-compose.test.yml logs -f test-runner
	@CONTAINER_ID=$$(docker-compose -f tests/docker-compose.test.yml ps -aq test-runner); \
	EXIT_CODE=$$(docker inspect -f '{{.State.ExitCode}}' $$CONTAINER_ID 2>/dev/null || echo 1); \
	docker-compose -f tests/docker-compose.test.yml down -v >/dev/null 2>&1; \
	exit $$EXIT_CODE

test-verbose: build
	docker-compose -f tests/docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from test-runner
	docker-compose -f tests/docker-compose.test.yml down -v

# Clean up all Docker resources related to this project
clean:
	@echo "Cleaning up Docker resources for $(IMAGE_NAME)..."
	@echo "→ Stopping and removing test containers and volumes..."
	@docker-compose -f tests/docker-compose.test.yml down -v 2>/dev/null || true
	@echo "→ Removing Docker images..."
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@docker rmi tests-nfs-ganesha 2>/dev/null || true
	@echo "→ Removing stopped containers from this project..."
	@docker ps -a --filter "ancestor=$(IMAGE_NAME):$(IMAGE_TAG)" --format "{{.ID}}" | xargs -r docker rm 2>/dev/null || true
	@docker ps -a --filter "ancestor=tests-nfs-ganesha" --format "{{.ID}}" | xargs -r docker rm 2>/dev/null || true
	@echo "→ Pruning dangling images from builds..."
	@docker image prune -f --filter "label=maintainer=mkletzan@redhat.com" 2>/dev/null || true
	@echo "✓ Cleanup complete"
