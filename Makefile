.PHONY: dev build up down logs analyze test \
        tf-init tf-import tf-plan tf-apply tf-destroy

# Run locally with hot reload at http://localhost:8080
dev:
	fvm flutter run -d web-server --web-port 8080

# Build and run the production Docker container at http://localhost:80
up:
	docker compose up -d

down:
	docker compose down

build:
	docker compose build

logs:
	docker compose logs -f

analyze:
	fvm flutter analyze

test:
	fvm flutter test

# ── Terraform ────────────────────────────────────────────────────────────────

tf-init:
	cd terraform && terraform init

# First-time only: imports existing GCP resources, then delete terraform/imports.tf
tf-import:
	cd terraform && terraform apply

tf-plan:
	cd terraform && terraform plan

tf-apply:
	cd terraform && terraform apply

tf-destroy:
	cd terraform && terraform destroy
