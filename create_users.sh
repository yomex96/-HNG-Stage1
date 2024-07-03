#!/bin/bash

# Author: Abayomi Robert Onawole
# Description: This Bash script automates user creation, group management, and password generation for new employees based on a user list file.
# Date: 03/07/2024

#############################################################

########### HOW TO USE ###########################

# 1. Create a text file (e.g., user_list.txt) containing user information in the format username;groups (one user per line).
# 2. Make the script executable: chmod +x create_users.sh
# 3. Run the script: sudo ./create_users.sh <user_list.txt>

###########################################################

# Function to log messages with timestamps
log_message() {
  local message="$1"
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Ensure script is run with root privileges
if [[ "$(id -u)" -ne 0 ]]; then
  echo "This script must be run with root or sudo privileges." >&2
  log_message "Script not run as root or with sudo privileges"
  exit 1
fi

# Check if user list file path is provided as argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <USER_LIST_FILE>" >&2
  exit 1
fi

# Define file paths in uppercase
USER_FILE="$1"  # Assigns the first argument (user list file path) to USER_FILE variable
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Check if user list file exists
if [ ! -f "$USER_FILE" ]; then
  echo "User list file '$USER_FILE' not found. Please check the path." >&2
  exit 1
fi

# Create the log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 666 "$LOG_FILE"
    log_message "Log file created: $LOG_FILE"
fi

# Create the password file if it doesn't exist
if [ ! -f "$PASSWORD_FILE" ]; then
    mkdir -p /var/secure
    touch "$PASSWORD_FILE"
    chmod 666 "$PASSWORD_FILE"
    log_message "Password file created: $PASSWORD_FILE"
fi

# Function to generate strong random passwords
generate_password() {
  < /dev/urandom tr -dc 'A-Za-z0-9!@#$%^&*()_+=' | head -c 12
}

# Function to create user, group, set permissions, and log actions
create_user() {
  local username="$1"
  local groups="$2"

  log_message "Creating user: $username"

  # Check if user already exists
  if id "$username" >/dev/null 2>&1; then
    log_message "User $username already exists. Skipping..."
    return 1
  fi

  # Create personal user group
  groupadd "$username" &>> "$LOG_FILE"

  # Create user with home directory
  useradd -m -g "$username" "$username" &>> "$LOG_FILE"

  # Set home directory permissions
  chown -R "$username:$username" "/home/$username" &>> "$LOG_FILE"
  chmod 700 "/home/$username" &>> "$LOG_FILE"

  # Add user to additional groups (if any)
  for group in $(echo "$groups" | tr ',' ' '); do
    if ! grep -q "^$group:" /etc/group; then
      groupadd "$group" &>> "$LOG_FILE"
    fi
    usermod -a -G "$group" "$username" &>> "$LOG_FILE"
  done

  # Generate a strong random password
  local password
  password=$(generate_password)
  log_message "Generated password for $username"

  echo "$username,$password" >> "$PASSWORD_FILE"
  chmod 666 "$PASSWORD_FILE" &>> "$LOG_FILE"

  # Set user password
  echo "$username:$password" | chpasswd &>> "$LOG_FILE"

  log_message "User $username created successfully."
}

# Validate username and groups
validate_username() {
    if [[ ! "$1" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    return 0
}

validate_groups() {
    IFS=',' read -ra group_list <<< "$1"
    for group in "${group_list[@]}"; do
        if [[ ! "$group" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            return 1
        fi
    done
    return 0
}

# Read the user file line by line
while IFS=';' read -r username groups; do
    # Trim whitespace from username and groups
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Check if the username and groups are not empty and valid
    if [ -z "$username" ] || [ -z "$groups" ]; then
        log_message "Invalid line format in user file: '$username;$groups'"
        continue
    fi

    if ! validate_username "$username"; then
        log_message "Invalid username format: '$username'"
        continue
    fi

    if ! validate_groups "$groups"; then
        log_message "Invalid group format: '$groups'"
        continue
    fi

    # Create the user and add to the groups
    create_user "$username" "$groups"

done < "$USER_FILE"

echo "User creation completed. Please refer to the log file for details: $LOG_FILE"

exit 0

