#!/usr/bin/env bash
set -euo pipefail

V35_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$V35_DIR/config.local.sh" ]]; then
  # shellcheck source=/dev/null
  source "$V35_DIR/config.local.sh"
fi
: "${SUBSCRIPTION_ID:?Ange SUBSCRIPTION_ID i config.local.sh.}"
: "${TENANT_ID:?Ange TENANT_ID i config.local.sh.}"
: "${TENANT_DOMAIN:?Ange TENANT_DOMAIN i config.local.sh.}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-novatrix}"
LOCATION="${LOCATION:-swedencentral}"
IDENTITY_NAME="${IDENTITY_NAME:-id-novatrix-app}"
VM_NAME="${VM_NAME:-vm-novatrix-web}"
[[ "$TENANT_DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]] || { echo "Ogiltig tenantdomän." >&2; exit 1; }
[[ "$RESOURCE_GROUP" =~ ^[a-zA-Z0-9._-]+$ ]] || { echo "Ogiltigt resursgruppsnamn." >&2; exit 1; }
command -v az >/dev/null || { echo "Azure CLI saknas. Använd Azure Cloud Shell, Bash." >&2; exit 1; }
az account set --subscription "$SUBSCRIPTION_ID"
ACTUAL_TENANT="$(az account show --query tenantId -o tsv)"
STATE="$(az account show --query state -o tsv)"
[[ "$ACTUAL_TENANT" == "$TENANT_ID" ]] || { echo "Fel tenant. Avbryter." >&2; exit 1; }
[[ "$STATE" == "Enabled" ]] || { echo "Prenumerationen är $STATE. Inga ändringar görs." >&2; exit 1; }
SCOPE="$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)"
DRIFT_UPN="novatrix-drift@$TENANT_DOMAIN"
DEV_UPN="novatrix-utveckling@$TENANT_DOMAIN"
DRIFT_GROUP="grp-novatrix-drift"
DEV_GROUP="grp-novatrix-utveckling"
