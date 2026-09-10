#!/usr/bin/env bash
# Description: Interactively pulls and downloads an individual shell script from
# a specified folder within the remote GitHub repository, then makes it executable.

# Configuration
REPO_OWNER="77777kaz77777"
REPO_NAME="linux-environment-automation"
BRANCH="main"

# Available folders identified from repository layout
VALID_FOLDERS=("configs" "desktop-tweaks" "security" "updates" "utils")

echo "Select a folder to pull from:"
select FOLDER in "${VALID_FOLDERS[@]}"; do
  if [ -n "$FOLDER" ]; then
    break
  else
    echo "Invalid selection. Please choose a valid number."
  fi
done

read -rp "Enter the script name (e.g., create-script-template.sh): " SCRIPT

if [ -z "$SCRIPT" ]; then
  echo "Error: Script name cannot be empty."
  exit 1
fi

RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/${FOLDER}/${SCRIPT}"

echo "Fetching ${SCRIPT} from ${FOLDER}..."
curl -fLO "$RAW_URL"

if [ $? -eq 0 ]; then
  echo "Successfully downloaded ${SCRIPT}"
  chmod +x "$SCRIPT"
  echo "Made ${SCRIPT} executable."
else
  echo "Error: Failed to download file. Please check the script name."
  exit 1
fi
