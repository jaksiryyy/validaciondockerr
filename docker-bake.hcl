# Configuración para Docker Bake
variable "TAG" {
  default = "latest"
}

variable "REGISTRY" {
  default = "ghcr.io"
}

variable "REPO" {
  default = "tu-usuario/tu-repo"
}

# Grupo por defecto
group "default" {
  targets = ["app"]
}

# Grupo para todas las plataformas
group "multi-platform" {
  targets = ["app-multi"]
}

# Target principal
target "app" {
  context = "."
  dockerfile = "Dockerfile"
  tags = [
    "${REGISTRY}/${REPO}:${TAG}",
    "${REGISTRY}/${REPO}:latest"
  ]
  platforms = ["linux/amd64"]
}

# Target multi-plataforma
target "app-multi" {
  inherits = ["app"]
  platforms = [
    "linux/amd64",
    "linux/arm64"
  ]
}

# Target para desarrollo
target "dev" {
  inherits = ["app"]
  tags = ["${REPO}:dev"]
  target = "development"
  cache-from = [
    "type=gha"
  ]
  cache-to = [
    "type=gha,mode=max"
  ]
}

# Target para producción
target "prod" {
  inherits = ["app"]
  tags = [
    "${REGISTRY}/${REPO}:${TAG}",
    "${REGISTRY}/${REPO}:prod"
  ]
  target = "production"
  cache-from = [
    "type=gha"
  ]
  cache-to = [
    "type=gha,mode=max"
  ]
}
