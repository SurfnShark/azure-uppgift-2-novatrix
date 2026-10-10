#!/usr/bin/env bash
# Inventering räcker inte för att bevisa least privilege: kör även verify-reader.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
VM_SCOPE="$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query id -o tsv)"

require_role() {
  local id="$1" role="$2" role_scope="$3" definition count
  definition="$(az role definition list --name "$role" --query '[0].id' -o tsv)"
  count="$(az role assignment list --scope "$role_scope" \
    --query "length([?principalId=='$id' && roleDefinitionId=='$definition' && scope=='$role_scope'])" -o tsv)"
  [[ "$count" -ge 1 ]] || { echo "Roll saknas: $role på $role_scope." >&2; exit 1; }
}

for entry in "$DRIFT_GROUP:$DRIFT_UPN" "$DEV_GROUP:$DEV_UPN"; do
  group="${entry%%:*}"
  upn="${entry#*:}"
  user_id="$(az ad user show --id "$upn" --query id -o tsv)"
  group_id="$(az ad group show --group "$group" --query id -o tsv)"
  [[ "$(az ad group member check --group "$group_id" --member-id "$user_id" --query value -o tsv)" == 'true' ]] \
    || { echo "Medlemskap saknas för $upn." >&2; exit 1; }
  require_role "$group_id" Reader "$SCOPE"
  if [[ "$group" == "$DRIFT_GROUP" ]]; then
    require_role "$group_id" 'Virtual Machine Contributor' "$VM_SCOPE"
  fi
  echo "Grupp: $group; medlem: $upn"
  az role assignment list --scope "$SCOPE" --include-inherited --all \
    --query "[?principalId=='$group_id'].{Role:roleDefinitionName,Scope:scope}" -o table
done

principal_id="$(az identity show --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --query principalId -o tsv)"
roles="$(az role assignment list --scope "$SCOPE" --include-inherited --all \
  --query "length([?principalId=='$principal_id'])" -o tsv)"
[[ "$roles" == '0' ]] || { echo "Appidentiteten har redan Azure-roller på/över resursgruppen. Kontrollera dem." >&2; exit 1; }
echo "Appidentiteten finns och har inga direkta/inherited Azure-roller på resursgruppen."
echo "Administratörens inventering klar. Utvecklarens läs- och nekade skrivtest återstår."
