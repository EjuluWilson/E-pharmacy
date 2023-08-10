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

check_existing_username() {
    username=$1
    ## verify if a username is already included in the credentials file
    grep "^$username:" $credentials_file > /dev/null
    return $?
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
    if [ $? -eq 0 ]; then
        echo "Username already exists. Please choose a different username."
        return 1
    fi

    ## retrieve the role. Defaults to "normal" if the 4th argument is not passed
    role=${4:-normal}

    ## check if the role is valid. Should be either normal, salesperson, or admin
    if [ "$role" != "normal" ] && [ "$role" != "salesperson" ] && [ "$role" != "admin" ]; then
        echo "Invalid role."
        return 1
    fi

    ## first generate a salt
    salt=`generate_salt`
    ## then hash the password with the salt
    hashed_pwd=`hash_password $password $salt`
    ## append the line in the specified format to the credentials file (see below)
    ## username:hash:salt:fullname:role:is_logged_in
    echo "$username:$hashed_pwd:$salt:$fullname:$role:0" >> $credentials_file
}

# Function to verify credentials
verify_credentials() {
    ## arg1 is username
    ## arg2 is password
    username=$1
    password=$2

    ## retrieve the stored hash, and the salt from the credentials file
    # if there is no line, then return 1 and output "Invalid username"
    line=$(grep "^$username:" $credentials_file)
    if [ -z "$line" ]; then
        echo "Invalid username"
        return 1
    fi

    ## compute the hash based on the provided password
    stored_hash=$(echo $line | cut -d':' -f2)
    stored_salt=$(echo $line | cut -d':' -f3)
    computed_hash=$(hash_password $password $stored_salt)

    ## compare to the stored hash
    ### if the hashes match, update the credentials file, override the .logged_in file with the
    ### username of the logged in user
    if [ "$stored_hash" = "$computed_hash" ]; then
        echo $username > .logged_in
        sed -i "s/^\($username:[^:]*:[^:]*:[^:]*:[^:]*:\)0$/\11/" "$credentials_file"
        role=$(echo $line | cut -d':' -f5)
        export role
        return 0
    else
        ### else, print "invalid password" and fail.
        echo "Invalid password"
        return 1
    fi
}

logout() {
    #TODO: check that the .logged_in file is not empty
    # if the file exists and is not empty, read its content to retrieve the username
    # of the currently logged in user
    if [ -f .logged_in ] && [ -s .logged_in ]; then
        username=$(cat .logged_in)
        # then delete the existing .logged_in file and update the credentials file by changing the last field to 0
        sed -i "s/^\($username:[^:]*:[^:]*:[^:]*:[^:]*:\)1$/\10/" "$credentials_file"
        rm .logged_in
        echo "Logged out."
    else
        echo "No user is currently logged in."
    fi
}

# ... Main script execution, menus, and other functions ...

#### BONUS
#1. Implement a function to delete an account from the file

## Function to create an admin user
create_admin() {
    read -p 'Admin Username: ' admin_user
    read -sp 'Admin Password: ' admin_pass
    echo
    read -p 'Admin Full Name: ' admin_fullname
    
    # Prompt for admin credentials to allow admin creation
    echo "Enter your admin credentials to proceed:"
    get_credentials

    # Verify admin credentials before allowing admin creation
    verify_credentials "$user" "$pass"
    if [ $? -eq 0 ] && [ "$role" = "admin" ]; then
        register_credentials "$admin_user" "$admin_pass" "$admin_fullname" "admin"
        echo "Admin created."
    else
        echo "Insufficient permissions. Only admin users can create admins."
    fi
}

## Main script execution starts here
echo "Welcome to the authentication system."

while true; do
    if [ ! -f .logged_in ]; then
        echo "1. Login"
        echo "2. Register User"
        echo "3. Exit"
        read -p "Choose an option: " choice

        case $choice in
            1)  # Login logic
                get_credentials
                verify_credentials "$user" "$pass"
                if [ $? -eq 0 ]; then
                    echo "Logged in as $user."
                else
                    echo "Login failed."
                fi
                ;;
            2)  # User registration logic
                read -p 'Username: ' username
                read -sp 'Password: ' password
                echo
                read -p 'Full Name: ' fullname
                register_credentials "$username" "$password" "$fullname"
                echo "User registered."
                ;;
            3)  echo "Exiting."
                exit 0
                ;;
            *)  echo "Invalid choice. Please choose a valid option."
                ;;
        esac
    else
        echo "1. Logout"
        echo "2. Create Admin"
        echo "3. Create Salesperson"
        read -p "Choose an option (Admin menu): " choice

        case $choice in
            1)  # Logout logic
                logout
                ;;
            2)  # Admin creation logic
                create_admin
                ;;
            3)  # Salesperson creation logic
                # Assuming the logic is similar to the admin creation
                read -p 'Salesperson Username: ' salesperson_user
                read -sp 'Salesperson Password: ' salesperson_pass
                echo
                read -p 'Salesperson Full Name: ' salesperson_fullname

                echo "Enter your admin credentials to proceed:"
                get_credentials

                verify_credentials "$user" "$pass"
                if [ $? -eq 0 ] && [ "$role" = "admin" ]; then
                    register_credentials "$salesperson_user" "$salesperson_pass" "$salesperson_fullname" "salesperson"
                    echo "Salesperson created."
                else
                    echo "Insufficient permissions. Only admin users can create salespersons."
                fi
                ;;
            *)  echo "Invalid choice. Please choose a valid option."
                ;;
        esac
    fi
done
