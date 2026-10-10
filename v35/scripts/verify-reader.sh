#!/usr/bin/env bash
# Kör i en separat CLI-inloggning som Novatrix Utveckling, inte administratören.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
caller="$(az account show --query user.name -o tsv)"
[[ "${caller,,}" == "${DEV_UPN,,}" ]] || { echo "Fel testkonto: logga in som $DEV_UPN." >&2; exit 1; }

az group show --name "$RESOURCE_GROUP" --query '{Name:name,Location:location}' -o table
echo "PASS: utvecklaren kan läsa resursgruppen."

# En PATCH med oförändrade taggar testar write-rättigheten utan att avsiktligt ändra data.
body="$(az group show --name "$RESOURCE_GROUP" --query '{tags:tags}' -o json)"
error_file="$(mktemp)"
trap 'rm -f "$error_file"' EXIT
if az rest --method patch --url "https://management.azure.com${SCOPE}?api-version=2022-09-01" \
  --body "$body" -o none 2>"$error_file"; then
  echo "FAIL: utvecklaren kunde skriva. Kontrollera ärvda roller och gruppmedlemskap." >&2
  exit 1
fi
if grep -q 'AuthorizationFailed' "$error_file" && grep -q 'Microsoft.Resources/subscriptions/resourceGroups/write' "$error_file"; then
  echo "PASS: utvecklarens skrivförsök nekades på grund av behörigheten."
else
  echo "INTE VERIFIERAT: anropet misslyckades av en annan orsak än förväntat behörighetsfel." >&2
  cat "$error_file" >&2
  exit 1
fi
