.PHONY: dev build up down logs analyze test

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
