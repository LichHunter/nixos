#!/usr/bin/env bash

# Define the backup directory
BACKUP_DIR=~/Backup

# Create the backup directory if it doesn't exist
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Creating backup directory at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Define the backup file name with a timestamp
BACKUP_FILE="$BACKUP_DIR/backup-$(date -d "today" +"%Y%m%d%H%M").tar"

# Define the directories to be backed up
# Note: ~ is expanded by the shell, so it's used directly here.
DIRECTORIES_TO_BACKUP=(
    ~/.gnupg
    ~/.ssh
    ~/Documents
    ~/Pictures
    ~/org
    ~/nixos-dotfiles
    ~/nixos
    ~/hetzner-nixos
    ~/.authinfo.gpg
)

# Create the tar archive, excluding specified folders
echo "Starting backup..."
tar --exclude='.direnv' --exclude='.git' --exclude='node_modules' -cf "$BACKUP_FILE" "${DIRECTORIES_TO_BACKUP[@]}"

# Check if the tar command was successful
if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed."
    exit 1
fi

exit 0
