SHELL := /bin/bash
COMPOSE := docker compose -f docker/docker-compose.yml
NS ?= stockpilot-local
PYTHON ?= $(shell command -v python3.12 || command -v python3)

.PHONY: help
help: ## show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

.PHONY: install test lint
install: ## install backend + frontend deps locally
	cd application/backend && $(PYTHON) -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
	cd application/frontend && npm ci
test: ## run backend tests with coverage
	cd application/backend && .venv/bin/pytest --cov=app --cov-report=term
lint: ## ruff lint + format check
	cd application/backend && .venv/bin/ruff check . && .venv/bin/ruff format --check .

.PHONY: build up up-monitoring down
build: ## build both images
	docker build -f docker/backend.Dockerfile -t stockpilot-backend:local application/backend
	docker build -f docker/frontend.Dockerfile -t stockpilot-frontend:local application/frontend
up: ## run the full stack (http://localhost:3000)
	$(COMPOSE) up --build -d
up-monitoring: ## stack + Prometheus (9090) + Grafana (3001)
	$(COMPOSE) --profile monitoring up --build -d
down: ## stop the stack and delete its volume
	$(COMPOSE) --profile monitoring down -v

.PHONY: scan scan-images
scan: ## run SAST/SCA/secret/IaC gates locally
	./security/scan-local.sh
scan-images: ## also build + Trivy-scan images
	./security/scan-local.sh --images

.PHONY: kind bootstrap helm-lint helm-install helm-deploy raw-deploy break
kind: ## create a local kind cluster
	./scripts/kind-up.sh
bootstrap: ## ingress, metrics-server, secrets, Argo CD (add ARGS=--kind for kind)
	./scripts/bootstrap-cluster.sh $(ARGS)
helm-lint: ## lint + render the chart
	helm lint helm/stockpilot --set postgres.password=lint --set backend.image.tag=lint --set frontend.image.tag=lint
	helm template stockpilot helm/stockpilot --set postgres.password=lint --set backend.image.tag=lint --set frontend.image.tag=lint > /dev/null
helm-install: ## install with Helm directly (no Argo CD), using images built by `make build`
	kind load docker-image stockpilot-backend:local stockpilot-frontend:local --name stockpilot || true
	./scripts/create-db-secret.sh $(NS)
	helm upgrade --install stockpilot helm/stockpilot -n $(NS) --create-namespace -f helm/stockpilot/values-dev.yaml \
	  --set backend.image.repository=stockpilot-backend --set backend.image.tag=local \
	  --set frontend.image.repository=stockpilot-frontend --set frontend.image.tag=local \
	  --set postgres.existingSecret=stockpilot-db --set ingress.host=local.stockpilot.local --wait
kubernetes/db.env:
	@printf 'DB_USER=stockpilot\nDB_PASSWORD=%s\n' "$$(openssl rand -hex 16)" > $@
	@echo "generated $@ (random password, git-ignored)"
helm-deploy: ## real Helm release from GHCR images: make helm-deploy TAG=<commit-sha>
	@test -n "$(TAG)" || { echo "TAG=<commit-sha> is required"; exit 1; }
	./scripts/create-db-secret.sh stockpilot-helm
	helm upgrade --install stockpilot helm/stockpilot -n stockpilot-helm -f helm/stockpilot/values-dev.yaml \
	  --set backend.image.repository=$$(yq '.backend.image.repository' gitops/environments/dev/values.yaml) \
	  --set frontend.image.repository=$$(yq '.frontend.image.repository' gitops/environments/dev/values.yaml) \
	  --set backend.image.tag=$(TAG) --set frontend.image.tag=$(TAG) \
	  --set postgres.existingSecret=stockpilot-db --set ingress.host=helm.stockpilot.local --wait
raw-deploy: kubernetes/db.env ## deploy the plain manifests to stockpilot-raw
	kubectl apply -k kubernetes/
break: kubernetes/db.env ## apply a broken scenario: make break S=04-service-selector
	kubectl apply -k troubleshooting/scenarios/$(S)

.PHONY: tf-validate tf-plan tf-apply tf-destroy
tf-validate: ## fmt + validate (no AWS credentials needed)
	cd terraform && terraform fmt -check -recursive && terraform init -backend=false -input=false >/dev/null && terraform validate
tf-plan: ## terraform plan (needs AWS credentials)
	cd terraform && terraform init && terraform plan -out tfplan
tf-apply: ## apply the saved plan
	cd terraform && terraform apply tfplan
tf-destroy: ## destroy everything (stop the AWS bill)
	cd terraform && terraform destroy
