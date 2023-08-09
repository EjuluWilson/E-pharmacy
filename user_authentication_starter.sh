#!/bin/bash
## to be updated to match your settings
PROJECT_HOME="."
credentials_file="$PROJECT_HOME/data/credentials.txt"

# Function to prompt for credentials
get_credentials() {
    read -p 'Username: ' user
    read -rs -p 'Password: ' pass
    echo
}

# Function to generate a random salt using OpenSSL
generate_salt() {
    openssl rand -hex 8
    return 0
}

## function for hashing
hash_password() {
    # arg1 is the password
    # arg2 is the salt
    password=$1
    salt=$2
    # we are using the sha256 hash for this.
    echo -n "${password}${salt}" | sha256sum | awk '{print $1}'
    return 0
}

# Function to check if a username already exists
check_existing_username(){
    username=$1
    grep -q "^$username:" "$credentials_file" && return 0 || return 1
}

## function to add new credentials to the file
register_credentials() {
    # arg1 is the username
    # arg2 is the password
    # arg3 is the fullname of the user
    # arg4 (optional) is the role. Defaults to "normal"

    username=$1
    password=$2
    fullname=$3
    ## call the function to check if the username exists
    check_existing_username $username
    #TODO: if it exists, safely fails from the function.
    
    role=${4:-"normal"}

    #TODO: check if the role is valid. Should be either normal, salesperson, or admin

    # first generate a salt
    salt=$(generate_salt)
    # then hash the password with the salt
    hashed_pwd=$(hash_password "$password" "$salt")
    # append the line in the specified format to the credentials file (see below)
    echo "$username:$hashed_pwd:$salt:$fullname:$role:0" >> "$credentials_file"
}

# Function to verify credentials during login
verify_credentials() {
    ## arg1 is username
    ## arg2 is password
    username=$1
    password=$2
    ## retrieve the stored hash, and the salt from the credentials file
    credentials_line=$(grep "^$username:" "$credentials_file")
    if [ -z "$credentials_line" ]; then
        echo "Invalid username"
        return 1
    fi
    stored_hash=$(echo "$credentials_line" | cut -d: -f2)
    stored_salt=$(echo "$credentials_line" | cut -d: -f3)

    ## compute the hash based on the provided password
    computed_hash=$(hash_password "$password" "$stored_salt")

    ## compare to the stored hash
    if [ "$computed_hash" = "$stored_hash" ]; then
        echo "$username" > .logged_in
        sed -i "s/^$username:.*$/&:1/" "$credentials_file"
        return 0
    else
        echo "Invalid password"
        return 1
    fi
}

# Function to log out the current user
logout() {
    #TODO: check that the .logged_in file is not empty
    if [ -s .logged_in ]; then
        # if the file exists and is not empty, read its content to retrieve the username
        logged_in_user=$(cat .logged_in)
        # then delete the existing .logged_in file and update the credentials file by changing the last field to 0
        rm -f .logged_in
        sed -i "s/^$logged_in_user:.*$/&:0/" "$credentials_file"
    else
        echo "No user is logged in"
    fi
}

## Create the menu for the application
echo "Welcome to the authentication system."

#### BONUS
#1. Implement a function to delete an account from the file

while true; do
    echo "1. Login"
    echo "2. Register"
    echo "3. Exit"
    read -p "Choose an option: " choice

    case $choice in
        1)  get_credentials
            verify_credentials "$user" "$pass"
            if [ $? -eq 0 ]; then
                echo "Logged in as $user."
                # Provide menu for logged-in user (including admin menu if applicable)
                while true; do
                    echo "1. Log out"
                    # Add more menu options here (e.g., admin functions)
                    read -p "Choose an option: " user_option
                    case $user_option in
                        1)  logout
                            echo "Logged out."
                            break
                            ;;
                        # Add more cases for other menu options here
                    esac
                done
            fi
            ;;
        2)  get_credentials
            read -p 'Full Name: ' fullname
            register_credentials "$user" "$pass" "$fullname"
            if [ $? -eq 0 ]; then
                echo "Registration successful."
            else
                echo "Registration failed."
            fi
            ;;
        3)  echo "Exiting."
            exit 0
            ;;
        *)  echo "Invalid choice. Please choose a valid option."
            ;;
    esac
done