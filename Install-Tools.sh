#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
DJ_SAPER_DIR="/opt/djsaper"
WORDLIST_DIR="/usr/share/seclists/Discovery"
DIRECTORY_WORDLIST="$WORDLIST_DIR/Web-Content/directory-list-2.3-medium.txt"
SUBDOMAIN_WORDLIST="$WORDLIST_DIR/DNS/subdomains-top1million-110000.txt"
ZSHRC="$HOME/.zshrc"

# Function to update package list and install necessary packages
update_and_install_packages() {
    echo "----------------------------------------"
    echo "Updating package list and installing dependencies..."
    echo "----------------------------------------"
    sudo apt update -y
    sudo apt install -y docker-compose git feroxbuster seclists python3-pip
    echo "----------------------------------------"
    echo "Package installation completed."
    echo "----------------------------------------"
}

# Function to install BloodHound
install_bloodhound() {
    echo "----------------------------------------"
    echo "Starting installation of BloodHound..."
    echo "----------------------------------------"

    # Clone the BloodHound repository if it doesn't exist
    if [ ! -d "/opt/BloodHound" ]; then
        echo "Cloning BloodHound repository to /opt/BloodHound..."
        sudo git clone https://github.com/SpecterOps/BloodHound.git /opt/BloodHound
    else
        echo "/opt/BloodHound already exists. Skipping clone."
    fi

    # Navigate to the BloodHound directory
    cd /opt/BloodHound/

    # Copy Docker Compose example files
    echo "Setting up Docker Compose files..."
    sudo cp -n examples/docker-compose/* ./  # Use -n to avoid overwriting existing files
    echo "Docker Compose files set up successfully."

    # Start Docker Compose in detached mode
    echo "Starting BloodHound services with Docker Compose..."
    sudo docker-compose up -d

    # Wait for services to initialize
    echo "Waiting for services to initialize..."
    sleep 15  # Adjust the sleep duration as needed

    # Retrieve logs and extract the BloodHound initial password
    echo "Retrieving BloodHound initial password from Docker Compose logs..."
    LOGS=$(sudo docker-compose logs)
    PASSWORD=$(echo "$LOGS" | grep -i "Initial Password Set To:" | awk -F'Initial Password Set To: ' '{print $2}' | tr -d '\r')

    if [ -z "$PASSWORD" ]; then
        echo "Failed to retrieve the BloodHound initial password. Please check the Docker Compose logs manually."
    else
        echo "----------------------------------------"
        echo "BloodHound has been installed successfully."
        echo "BloodHound Initial Password: $PASSWORD"
        echo "----------------------------------------"
    fi

    # Navigate back to the original directory
    cd -
}

# Function to install Feroxbuster scripts
install_feroxbuster_scripts() {
    echo "----------------------------------------"
    echo "Setting up Feroxbuster scripts in $DJ_SAPER_DIR..."
    echo "----------------------------------------"

    # Create the directory if it doesn't exist
    sudo mkdir -p "$DJ_SAPER_DIR"

    # Define script contents
    FEROS_WINDOWS_CONTENT='#!/bin/bash

# Script: feroxbuster_windows.sh
# Description: Runs feroxbuster with Windows-specific flags for directory enumeration.

# Check if at least one argument (URL) is provided
if [ -z "$1" ]; then
    echo "Usage: feroxbuster_windows.sh <URL> [threads]"
    exit 1
fi

URL="$1"
THREADS="${2:-100}"  # Default to 100 threads if not specified

feroxbuster --url "$URL" \
            -r \
            -t "$THREADS" \
            -w '"$DIRECTORY_WORDLIST"' \
            -C 404,403,400,503,500,501,502 \
            -x exe,bat,msi,cmd,ps1 \
            --dont-scan "vendor,fonts,images,css,assets,docs,js,static,img,help"
'

    FEROS_LINUX_CONTENT='#!/bin/bash

# Script: feroxbuster_linux.sh
# Description: Runs feroxbuster with Linux-specific flags for directory enumeration.

# Check if at least one argument (URL) is provided
if [ -z "$1" ]; then
    echo "Usage: feroxbuster_linux.sh <URL> [threads]"
    exit 1
fi

URL="$1"
THREADS="${2:-100}"  # Default to 100 threads if not specified

feroxbuster --url "$URL" \
            -r \
            -t "$THREADS" \
            -w '"$DIRECTORY_WORDLIST"' \
            -C 404,403,400,503,500,501,502 \
            -x txt,sh,zip,bak,py,php \
            --dont-scan "vendor,fonts,images,css,assets,docs,js,static,img,help"
'

    FEROS_SUBDOMAIN_CONTENT='#!/bin/bash

# Script: feroxbuster_subdomain.sh
# Description: Runs feroxbuster for subdomain enumeration.

# Check if at least one argument (DOMAIN) is provided
if [ -z "$1" ]; then
    echo "Usage: feroxbuster_subdomain.sh <DOMAIN> [threads]"
    exit 1
fi

DOMAIN="$1"
THREADS="${2:-100}"  # Default to 100 threads if not specified

feroxbuster --domain "$DOMAIN" \
            -r \
            -t "$THREADS" \
            -w '"$SUBDOMAIN_WORDLIST"' \
            --subdomains \
            --silent
'

    # Create feroxbuster_windows.sh
    echo "Creating feroxbuster_windows.sh..."
    echo "$FEROS_WINDOWS_CONTENT" | sudo tee "$DJ_SAPER_DIR/feroxbuster_windows.sh" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/feroxbuster_windows.sh"

    # Create feroxbuster_linux.sh
    echo "Creating feroxbuster_linux.sh..."
    echo "$FEROS_LINUX_CONTENT" | sudo tee "$DJ_SAPER_DIR/feroxbuster_linux.sh" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/feroxbuster_linux.sh"

    # Create feroxbuster_subdomain.sh
    echo "Creating feroxbuster_subdomain.sh..."
    echo "$FEROS_SUBDOMAIN_CONTENT" | sudo tee "$DJ_SAPER_DIR/feroxbuster_subdomain.sh" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/feroxbuster_subdomain.sh"

    echo "----------------------------------------"
    echo "Feroxbuster scripts created successfully in $DJ_SAPER_DIR."
    echo "----------------------------------------"
}

# Function to install Arsenal
install_arsenal() {
    echo "----------------------------------------"
    echo "Starting installation of Arsenal..."
    echo "----------------------------------------"

    # Install Arsenal via pip
    echo "Installing Arsenal using pip..."
    sudo python3 -m pip install arsenal-cli
    echo "Arsenal installed successfully."

    # Add alias to .zshrc if not already present
    if grep -q "alias a='arsenal'" "$ZSHRC"; then
        echo "Alias 'a' for 'arsenal' already exists in $ZSHRC."
    else
        echo "Adding alias 'a' for 'arsenal' to $ZSHRC..."
        echo "alias a='arsenal'" | sudo tee -a "$ZSHRC" > /dev/null
        echo "Alias added successfully."
    fi

    # Reload zsh configuration
    echo "Reloading zsh configuration..."
    source "$ZSHRC"

    echo "----------------------------------------"
    echo "Arsenal has been installed and is accessible via the 'a' alias."
    echo "----------------------------------------"
}

# Placeholder functions for options 4 (Future Implementations)
install_option3() {
    echo "----------------------------------------"
    echo "Option 3 is not implemented yet."
    echo "----------------------------------------"
}

install_option4() {
    echo "----------------------------------------"
    echo "Option 4 is not implemented yet."
    echo "----------------------------------------"
}

# Function to display the menu and get user selection
show_menu() {
    echo "----------------------------------------"
    echo "Please select a tool to install:"
    echo "1. BloodHound"
    echo "2. Feroxbuster"
    echo "3. Arsenal"
    echo "4. [Option 4]"
    echo "A. All of the above"
    echo "----------------------------------------"
    echo -n "Enter your choice (1-4 or A): "
    read -r choice
}

# Function to handle the user's selection
handle_selection() {
    case "$choice" in
        1)
            install_bloodhound
            ;;
        2)
            install_feroxbuster_scripts
            ;;
        3)
            install_arsenal
            ;;
        4)
            install_option4
            ;;
        A|a)
            install_bloodhound
            install_feroxbuster_scripts
            install_arsenal
            install_option4
            ;;
        *)
            echo "----------------------------------------"
            echo "Invalid selection. Please run the script again and choose a valid option."
            echo "----------------------------------------"
            exit 1
            ;;
    esac
}

# Function to add /opt/djsaper/ to PATH in zsh
add_to_path_zsh() {
    echo "----------------------------------------"
    echo "Adding /opt/djsaper/ to PATH in $ZSHRC..."
    echo "----------------------------------------"

    # Check if /opt/djsaper/ is already in PATH
    if grep -q 'export PATH=.*\/opt/djsaper/' "$ZSHRC"; then
        echo "/opt/djsaper/ is already in your PATH."
    else
        echo 'export PATH="$PATH:/opt/djsaper/"' | sudo tee -a "$ZSHRC" > /dev/null
        echo "/opt/djsaper/ added to PATH successfully."
    fi

    # Reload zsh configuration
    echo "Reloading zsh configuration..."
    source "$ZSHRC"
}

# Function to set up Feroxbuster scripts and update PATH
setup_feroxbuster() {
    install_feroxbuster_scripts
    add_to_path_zsh
}

# Function to create symbolic links for easier access (Optional)
create_symlinks() {
    echo "----------------------------------------"
    echo "Creating symbolic links for Feroxbuster scripts..."
    echo "----------------------------------------"
    # This step is optional as /opt/djsaper/ is already in PATH
    # Uncomment the lines below if you prefer creating symlinks in /usr/local/bin/
    # sudo ln -s /opt/djsaper/feroxbuster_windows.sh /usr/local/bin/feroxbuster_windows
    # sudo ln -s /opt/djsaper/feroxbuster_linux.sh /usr/local/bin/feroxbuster_linux
    # sudo ln -s /opt/djsaper/feroxbuster_subdomain.sh /usr/local/bin/feroxbuster_subdomain
    echo "Symbolic links creation is optional and not performed by this script."
    echo "You can manually create symlinks if needed."
}

# Main script execution
main() {
    echo "========================================"
    echo "Welcome to the Tool Installation Script"
    echo "========================================"

    update_and_install_packages
    show_menu
    handle_selection

    # If Feroxbuster was installed, set up the scripts and update PATH
    if [[ "$choice" == "2" || "$choice" == "A" || "$choice" == "a" ]]; then
        setup_feroxbuster
    fi

    # If Arsenal was installed, ensure the alias is set
    if [[ "$choice" == "3" || "$choice" == "A" || "$choice" == "a" ]]; then
        echo "----------------------------------------"
        echo "You can now use the 'a' alias to launch Arsenal."
        echo "For example:"
        echo "    a"
        echo "----------------------------------------"
    fi

    echo "----------------------------------------"
    echo "Installation process completed."
    echo "----------------------------------------"
    echo "If you installed Feroxbuster, you can now use the following scripts from anywhere:"
    echo " - feroxbuster_windows.sh <URL> [threads]"
    echo " - feroxbuster_linux.sh <URL> [threads]"
    echo " - feroxbuster_subdomain.sh <DOMAIN> [threads]"
    echo "----------------------------------------"
}

# Run the main function
main
