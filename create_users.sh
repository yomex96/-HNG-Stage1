#!/bin/bash

# Check if running as root
if [[ $UID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

#Check if the file with users and their corresponding groups exists
if ["$#" -ne 1]; then
    echo "Use: $0 <user_file>"
    exit 1
fi

USER_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create the log and password files if they do not exist
touch $LOG_FILE
mkdir -p /var/secure
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Create a user function
create_user() {

    #declare the variables with local scope and assign them a value
    local user = $1
    local groups = $2
    local password

    # Check if user already exists
    if id "$user" &>/dev/null; then
        #Creates the user and logs the process
        echo "User $user already exists " | tee -a $LOG_FILE
        return 1
    fi

    #Create users personal group
    #Use the groupadd command used in unix OS to create a new group
    #The new group has the same name as the user  
    groupadd "$user"

    
    #Use the useradd command to create a new user
    #The -m flag creates a home directory for the user if it does not exist
    #The -g flag assigns the user to the group
    #The -G flag assigns the user to additional groups
    #The 2>>$LOG_FILE redirects the standard error to the log file
    useradd -m -g "$user" -G "$groups" "$user" 2>>$LOG_FILE

    #Check if the user group was created successfully
    if [ $? -ne 0 ]; then
        echo "Failed to create group $user" | tee -a $LOG_FILE
        return 1
    fi

    #Generate a random password
    password=$(openssl rand -base64 15 )

    #Set users password
    #Outputs the user and password to the chpasswd command
    #The chpasswd command reads eads a list of user name and password pairs from standard input 
    #and updates the system password file
    echo "$user:$password" | chpasswd
    if [ $? -ne 0 ]; then
        echo "Failed to set password for user $user" | tee -a $LOG_FILE
        return 1
    fi

    #Store the password securely
    #The password is stored in the /var/secure/user_passwords.txt file
    #The file is created if it does not exist
    #The file permissions are set to 600
    echo "$user:$password" >> $PASSWORD_FILE

    #Log the user creation
    echo "Created user $user with groups $groups" | tee -a $LOG_FILE
    
}


#Read the user file line by line
#The IFS variable is used to set the field separator to ';'
#The read command reads the user and groups from the file
while IFS=';' read -r user groups; do
    #The xargs command is used to remove leading and trailing whitespaces
    user=$(echo $user | xargs)
    groups=$(echo $groups | xargs)

    #The create_user function is called with the user and groups as arguments
    create user "user" "groups"
done < "$USER_FILE"

#Log the completion of the user creation process
echo "User creation process completed,Check the log file at $LOG_FILE and passwords at $PASSWORD_FILE." | tee -a $LOG_FILE
