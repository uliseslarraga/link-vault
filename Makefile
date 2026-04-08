DOCKER = podman
COMPOSE = $(DOCKER) compose -f infra/compose/docker-compose.dev.yml
ENV_FILE = .env

.PHONY: up down build logs ps restart clean seed

## Start all services (build if needed)
up:
	@cp -n .env.example $(ENV_FILE) 2>/dev/null || true
	$(COMPOSE) up --build -d
	@echo ""
	@echo "  Frontend → http://localhost:3000"
	@echo "  Backend  → http://localhost:8000"
	@echo "  API docs → http://localhost:8000/docs"
	@echo ""

## Stop all services
down:
	$(COMPOSE) down

## Rebuild images without cache
build:
	$(COMPOSE) build --no-cache

## Follow logs for all services (or: make logs s=backend)
logs:
	$(COMPOSE) logs -f $(s)

## Show running containers and health status
ps:
	$(COMPOSE) ps

## Restart a single service: make restart s=backend
restart:
	$(COMPOSE) restart $(s)

## Tear down + remove volumes (full reset)
clean:
	$(COMPOSE) down -v --remove-orphans

## Seed the DB with sample links
seed:
	$(COMPOSE) exec backend python -c "\
import asyncio, httpx; \
links = [ \
  {'url': 'https://fastapi.tiangolo.com', 'title': 'FastAPI Docs', 'note': 'Great async framework'}, \
  {'url': 'https://docs.docker.com', 'title': 'Docker Docs', 'note': 'Container reference'}, \
  {'url': 'https://kubernetes.io/docs', 'title': 'Kubernetes Docs', 'note': 'K8s reference'}, \
]; \
[httpx.post('http://localhost:8000/api/v1/links/', json=l) for l in links]; \
print('Seeded 3 links.')"
