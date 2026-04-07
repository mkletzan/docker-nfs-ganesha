.PHONY: build clean install-build-deps

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

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

clean:
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
