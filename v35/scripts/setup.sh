#!/usr/bin/env bash
# Körs av labbadministratören. Skriptet startar ingen VM.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
MARKER="Novatrix labb v35 - managed by v35/scripts/setup.sh"

ensure_user() {
  local upn="$1" display="$2" id existing_display password confirm
  id="$(az ad user list --filter "userPrincipalName eq '$upn'" --query '[0].id' -o tsv)"
  if [[ -n "$id" ]]; then
    existing_display="$(az ad user show --id "$id" --query displayName -o tsv)"
    [[ "$existing_display" == "$display" ]] || { echo "Befintlig användare $upn har annat namn. Avbryter." >&2; exit 1; }
  else
    echo "Skapar labbanvändare: $display ($upn)." >&2
    read -r -s -p "Ange ett unikt tillfälligt lösenord (sparas inte i repo): " password </dev/tty
    echo >&2
    read -r -s -p "Upprepa lösenordet: " confirm </dev/tty
    echo >&2
    [[ -n "$password" && "$password" == "$confirm" ]] || { echo "Lösenorden matchar inte." >&2; exit 1; }
    id="$(az ad user create --display-name "$display" --user-principal-name "$upn" \
      --password "$password" --force-change-password-next-sign-in true --query id -o tsv)"
    unset password confirm
  fi
  printf '%s\n' "$id"
}

ensure_group() {
  local name="$1" user_id="$2" id description member raw
  local -a matches
  raw="$(az ad group list --filter "displayName eq '$name'" --query '[].id' -o tsv)"
  matches=()
  if [[ -n "$raw" ]]; then mapfile -t matches <<< "$raw"; fi
  [[ ${#matches[@]} -le 1 ]] || { echo "Flera grupper heter $name. Avbryter." >&2; exit 1; }
  id="${matches[0]:-}"
  if [[ -z "$id" ]]; then
    id="$(az ad group create --display-name "$name" --mail-nickname "$name" \
      --description "$MARKER" --query id -o tsv)"
  else
    description="$(az ad group show --group "$id" --query description -o tsv)"
    [[ "$description" == "$MARKER" ]] || { echo "Gruppen $name är inte märkt som vår labbgrupp. Avbryter." >&2; exit 1; }
  fi
  # Ge inte en befintlig grupp med okända medlemmar nya Azure-behörigheter.
  local members
  members="$(az ad group member list --group "$id" --query '[].id' -o tsv)"
  while IFS= read -r member; do
    [[ -z "$member" || "$member" == "$user_id" ]] || { echo "Oväntad medlem i $name. Avbryter." >&2; exit 1; }
  done <<< "$members"
  if [[ "$(az ad group member check --group "$id" --member-id "$user_id" --query value -o tsv)" != "true" ]]; then
    az ad group member add --group "$id" --member-id "$user_id" -o none
  fi
  printf '%s\n' "$id"
}

assign_role() {
  local group_id="$1" role="$2" role_scope="$3" definition existing
  definition="$(az role definition list --name "$role" --query '[0].id' -o tsv)"
  [[ -n "$definition" ]] || { echo "Roll saknas: $role" >&2; exit 1; }
  existing="$(az role assignment list --scope "$role_scope" \
    --query "[?principalId=='$group_id' && roleDefinitionId=='$definition' && scope=='$role_scope'].id" -o tsv)"
  if [[ -z "$existing" ]]; then
    az role assignment create --assignee-object-id "$group_id" --assignee-principal-type Group \
      --role "$role" --scope "$role_scope" -o none
  fi
}

echo "Mål: $RESOURCE_GROUP i vald prenumeration. Kräver Entra-rättigheter och rätt att tilldela Azure-roller."
VM_SCOPE="$(az vm show --resource-group "$RESOURCE_GROUP" --name "$VM_NAME" --query id -o tsv)"
DRIFT_ID="$(ensure_user "$DRIFT_UPN" 'Novatrix Drift')"
DEV_ID="$(ensure_user "$DEV_UPN" 'Novatrix Utveckling')"
DRIFT_GROUP_ID="$(ensure_group "$DRIFT_GROUP" "$DRIFT_ID")"
DEV_GROUP_ID="$(ensure_group "$DEV_GROUP" "$DEV_ID")"
assign_role "$DRIFT_GROUP_ID" Reader "$SCOPE"
assign_role "$DRIFT_GROUP_ID" 'Virtual Machine Contributor' "$VM_SCOPE"
assign_role "$DEV_GROUP_ID" Reader "$SCOPE"

APP_ID="$(az identity list --resource-group "$RESOURCE_GROUP" --query "[?name=='$IDENTITY_NAME'].id | [0]" -o tsv)"
if [[ -z "$APP_ID" ]]; then
  az identity create --resource-group "$RESOURCE_GROUP" --name "$IDENTITY_NAME" --location "$LOCATION" \
    --tags company=novatrix assignment=2 -o none
fi
echo "Konfiguration skapad. Appidentiteten får ingen Azure-roll och kopplas inte till lagring i denna uppgift."
echo "Verifiera med bash v35/scripts/verify-admin.sh, följt av det separata utvecklartestet."
