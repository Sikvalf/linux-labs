set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

PUSH=true
if [[ "${1:-}" == "--no-push" ]]; then
    PUSH=false
    shift
fi

if [[ -f "$LAB_DIR/.env" ]]; then
    env_image="$(grep -E '^APP_IMAGE=' "$LAB_DIR/.env" | tail -n1 | cut -d= -f2- || true)"
    env_tag="$(grep -E '^APP_TAG=' "$LAB_DIR/.env" | tail -n1 | cut -d= -f2- || true)"
    APP_IMAGE="${APP_IMAGE:-$env_image}"
    APP_TAG="${APP_TAG:-$env_tag}"
fi

IMAGE="${APP_IMAGE:-}"
if [[ -z "$IMAGE" ]]; then
    echo "Ошибка: не задано имя образа. Укажите APP_IMAGE в .env или окружении," >&2
    echo "например APP_IMAGE=docker.io/<логин>/lab2-app" >&2
    exit 1
fi

TAG="${1:-${APP_TAG:-}}"
if [[ -z "$TAG" ]]; then
    TAG="$(git -C "$LAB_DIR" rev-parse --short HEAD 2>/dev/null || echo "1.0.0")"
fi
if [[ "$TAG" == "latest" ]]; then
    echo "Ошибка: тег latest не используем — укажите конкретную версию" >&2
    exit 1
fi

GIT_SHA="$(git -C "$LAB_DIR" rev-parse --short HEAD 2>/dev/null || echo "nogit")"

echo "==> Сборка ${IMAGE}:${TAG}"
DOCKER_BUILDKIT=1 docker build \
    --build-arg "APP_VERSION=${TAG}" \
    --label "org.opencontainers.image.revision=${GIT_SHA}" \
    --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -t "${IMAGE}:${TAG}" \
    "$LAB_DIR/app"

echo "==> Размер образа:"
docker image ls "${IMAGE}:${TAG}" --format '    {{.Repository}}:{{.Tag}}  {{.Size}}'

if [[ "$PUSH" == true ]]; then
    echo "==> Выгрузка ${IMAGE}:${TAG} в registry"
    docker push "${IMAGE}:${TAG}"
    echo "==> Готово. На другой машине: docker pull ${IMAGE}:${TAG}"
else
    echo "==> Пуш пропущен (--no-push)"
fi
