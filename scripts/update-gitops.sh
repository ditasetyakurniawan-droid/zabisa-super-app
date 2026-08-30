#!/usr/bin/env bash
set -euo pipefail
SHA=${1:?git sha required}
echo "Update GitOps image tags to ${SHA}; ArgoCD remains deployment authority."
