#!/usr/bin/env bash
# Tillämpa samma RBAC-modell via CLI, även när rollerna redan finns.
set -euo pipefail
source "$(dirname "$0")/common.sh"

group_id() {
  local name="$1" expected_upn="$2" id description members
  id="$(az ad group show --group "$name" --query id -o tsv)"
  description="$(az ad group show --group "$id" --query description -o tsv)"
  [[ "$description" == 'Novatrix labb v35 - managed by v35/scripts/setup.sh' ]] || {
    echo "Fel labbmarkering för $name. Avbryter." >&2; exit 1;
  }
  members="$(az ad group member list --group "$id" --query '[].userPrincipalName' -o tsv)"
  [[ "$members" == "$expected_upn" ]] || {
    echo "Oväntade medlemmar i $name. Avbryter." >&2; exit 1;
  }
  printf '%s\n' "$id"
}

apply_role() {
  local group="$1" principal="$2" role="$3" scope="$4" definition role_id assignment count
  definition="$(az role definition list --name "$role" --query '[0].id' -o tsv)"
  [[ -n "$definition" ]] || { echo "Roll saknas: $role" >&2; exit 1; }
  role_id="${definition##*/}"
  # Återanvänd befintligt tilldelningsnamn. Ingen roll tas bort för att köras om.
  assignment="$(az role assignment list --scope "$scope" \
    --query "[?principalId=='$principal' && ends_with(roleDefinitionId, '$role_id')].name | [0]" -o tsv)"
  if [[ -z "$assignment" ]]; then
    assignment="$(python3 -c 'import uuid; print(uuid.uuid4())')"
  fi
  az role assignment create --name "$assignment" --assignee-object-id "$principal" \
    --assignee-principal-type Group --role "$definition" --scope "$scope" -o none
  count="$(az role assignment list --scope "$scope" \
    --query "length([?principalId=='$principal' && ends_with(roleDefinitionId, '$role_id')])" -o tsv)"
  [[ "$count" == 1 ]] || { echo "Oväntat antal tilldelningar: $group / $role" >&2; exit 1; }
  printf 'VERIFIERAD: %s | %s | %s\n' "$group" "$role" "$scope"
}

VM_SCOPE="$(az vm show -g "$RESOURCE_GROUP" -n "$VM_NAME" --query id -o tsv)"
DRIFT_ID="$(group_id "$DRIFT_GROUP" "$DRIFT_UPN")"
DEV_ID="$(group_id "$DEV_GROUP" "$DEV_UPN")"
apply_role "$DRIFT_GROUP" "$DRIFT_ID" Reader "$SCOPE"
apply_role "$DEV_GROUP" "$DEV_ID" Reader "$SCOPE"
apply_role "$DRIFT_GROUP" "$DRIFT_ID" 'Virtual Machine Contributor' "$VM_SCOPE"
echo 'VG: samtliga tre rolltilldelningar tillämpade och verifierade via Azure CLI.'
