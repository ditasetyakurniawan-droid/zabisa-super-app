#!/usr/bin/env bash
set -euo pipefail
SHA=${1:?git sha required}
HARBOR=${HARBOR:-harbor-dt.co.id}
PROJECT=${PROJECT:-zabisa}
for d in services/*; do
  [ -f "$d/Dockerfile" ] || continue
  name=$(basename "$d")
  image="$HARBOR/$PROJECT/$name:$SHA"
  docker build -f "$d/Dockerfile" -t "$image" .
  trivy image --exit-code 1 --severity CRITICAL,HIGH "$image"
  docker push "$image"
done
