#!/bin/bash

PAYLOAD_FMT='{"data":{"type":"vars","attributes":{"key":"%s","value":"%s","category":"%s","sensitive":%s}}}'

# Upserts Terraform Cloud workspace variables
upsertWorkspaceVariables() {
  # $1 - TFC_TOKEN
  # $2 - payload
  # $3 - workspace ID
  # $4 - variable type
  # $5 - variable key
  # $6 - variable ID

  # If variable ID is null, create variable
  if [ -z "$6" ]; then
    echo -e "\nAdding $4 variable $5."

    curl \
      --header "Authorization: Bearer "$1"" \
      --header "Content-Type: application/vnd.api+json" \
      --request POST \
      --data $2 \
      "https://app.terraform.io/api/v2/workspaces/"$3"/vars"
  # else update variable
  else
    echo -e "\nUpdating $4 variable $5."

    curl \
      --header "Authorization: Bearer "$1"" \
      --header "Content-Type: application/vnd.api+json" \
      --request PATCH \
      --data $2 \
      "https://app.terraform.io/api/v2/workspaces/"$3"/vars/"$6
  fi
}

# Get Terraform Cloud workspace IDs
workspaces=$(curl -s \
  --header "Authorization: Bearer "$TFC_TOKEN"" \
  --header "Content-Type: application/vnd.api+json" \
  "https://app.terraform.io/api/v2/organizations/"$ORG_NAME"/workspaces" |
  jq -r 'reduce (.data | .[]) as $o ({}; .[$o["attributes"]["name"]] = $o["id"])')

# echo $workspaces | jq '."learn-terraform-migrate-s3-backend-"'

# Loop through input file
for ws in $(cat workspace-variables.json | jq 'keys[]'); do
  wsID=$(echo $workspaces | jq -r '.'$ws'')
  echo -e "\n===============================\nAdding Variables to Workspace $ws\n==============================="

  # Get current workspace variables
  wsVars=$(curl -s \
    --header "Authorization: Bearer "$TFC_TOKEN"" \
    --header "Content-Type: application/vnd.api+json" \
    "https://app.terraform.io/api/v2/workspaces/"$wsID"/vars")

  # Loop through input list's Terraform variables
  for tfvar in $(cat workspace-variables.json | jq -r '.'$ws' | select(".tf-variables") | ."tf-variables"[]? | .key'); do
    val=$(cat workspace-variables.json | jq -r '.'$ws' | select(".tf-variables") | ."tf-variables"[]? | select(.key=="'$tfvar'") | .value')
    sensitive=$(cat workspace-variables.json | jq -r '.'$ws' | select(".tf-variables") | ."tf-variables"[]? | select(.key=="'$tfvar'") | .sensitive')

    payload=$(printf "$PAYLOAD_FMT" "$tfvar" "$val" "terraform" "$sensitive")
    # echo $payload

    # Get variable ID if it exists
    varID=$(echo $wsVars | jq -r '.data | .[] | select(.attributes.key=="'$tfvar'" and .attributes.category=="terraform") | .id')
    # Upsert variable
    upsertWorkspaceVariables $TFC_TOKEN $payload $wsID "terraform" $tfvar $varID
  done

  # Loop through environment variables
  for envVar in $(cat workspace-variables.json | jq -r '.'$ws' | select(".env-variables") | ."env-variables"[]? | .key'); do
    val=$(cat workspace-variables.json | jq -r '.'$ws' | select(".env-variables") | ."env-variables"[]? | select(.key=="'$envVar'") | .value')
    sensitive=$(cat workspace-variables.json | jq -r '.'$ws' | select(".env-variables") | ."env-variables"[]? | select(.key=="'$envVar'") | .sensitive')

    payload=$(printf "$PAYLOAD_FMT" "$envVar" "$val" "env" "$sensitive")
    # echo $payload

    # Get variable ID if it exists
    varID=$(echo $wsVars | jq -r '.data | .[] | select(.attributes.key=="'$envVar'" and .attributes.category=="env") | .id')
    # Upsert variable
    upsertWorkspaceVariables $TFC_TOKEN $payload $wsID "env" $envVar $varID
  done
done
