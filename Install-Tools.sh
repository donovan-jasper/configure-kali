#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
DJ_SAPER_DIR="/opt/djasper"
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
    sudo apt install -y docker-compose git feroxbuster gobuster seclists
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

# Script: feroxbuster_windows
# Description: Runs Feroxbuster with Windows-specific flags for directory enumeration.

# Check if at least one argument (URL) is provided
if [ -z "$1" ]; then
    echo "Usage: feroxbuster_windows <URL> [threads]"
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

# Script: feroxbuster_linux
# Description: Runs Feroxbuster with Linux-specific flags for directory enumeration.

# Check if at least one argument (URL) is provided
if [ -z "$1" ]; then
    echo "Usage: feroxbuster_linux <URL> [threads]"
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

    # Create feroxbuster_windows
    echo "Creating feroxbuster_windows..."
    echo "$FEROS_WINDOWS_CONTENT" | sudo tee "$DJ_SAPER_DIR/feroxbuster_windows" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/feroxbuster_windows"

    # Create feroxbuster_linux
    echo "Creating feroxbuster_linux..."
    echo "$FEROS_LINUX_CONTENT" | sudo tee "$DJ_SAPER_DIR/feroxbuster_linux" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/feroxbuster_linux"

    echo "----------------------------------------"
    echo "Feroxbuster scripts created successfully in $DJ_SAPER_DIR."
    echo "----------------------------------------"
}

# Function to install Gobuster scripts
install_gobuster_scripts() {
    echo "----------------------------------------"
    echo "Setting up Gobuster scripts in $DJ_SAPER_DIR..."
    echo "----------------------------------------"

    # Create the directory if it doesn't exist
    sudo mkdir -p "$DJ_SAPER_DIR"

    # Define gobuster_subdomains script content with relevant filtering
    GOBUSTER_SUBDOMAIN_CONTENT='#!/bin/bash

# Script: gobuster_subdomains
# Description: Runs Gobuster for subdomain enumeration with relevant status code filtering.

# Check if at least one argument (DOMAIN) is provided
if [ -z "$1" ]; then
    echo "Usage: gobuster_subdomains <DOMAIN> [threads]"
    exit 1
fi

DOMAIN="$1"
THREADS="${2:-100}"  # Default to 100 threads if not specified

# Define the status codes to filter (adjust as needed)
STATUS_CODES="200,204,301,302,307,401,403"

gobuster dns -d "$DOMAIN" -w '"$SUBDOMAIN_WORDLIST"' -t "$THREADS" -s "$STATUS_CODES"
'

    # Create gobuster_subdomains
    echo "Creating gobuster_subdomains..."
    echo "$GOBUSTER_SUBDOMAIN_CONTENT" | sudo tee "$DJ_SAPER_DIR/gobuster_subdomains" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/gobuster_subdomains"

    echo "----------------------------------------"
    echo "Gobuster scripts created successfully in $DJ_SAPER_DIR."
    echo "----------------------------------------"
}

# Placeholder functions for options 3 and 4
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
    echo "3. Gobuster"
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
            install_gobuster_scripts
            ;;
        4)
            install_option4
            ;;
        A|a)
            install_bloodhound
            install_feroxbuster_scripts
            install_gobuster_scripts
            install_option3
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

# Function to add /opt/djasper/ to PATH in zsh
add_to_path_zsh() {
    echo "----------------------------------------"
    echo "Adding /opt/djasper/ to PATH in $ZSHRC..."
    echo "----------------------------------------"

    # Check if /opt/djasper/ is already in PATH
    if grep -q 'export PATH=.*\/opt/djasper/' "$ZSHRC"; then
        echo "/opt/djasper/ is already in your PATH."
    else
        echo 'export PATH="$PATH:/opt/djasper/"' | sudo tee -a "$ZSHRC" > /dev/null
        echo "/opt/djasper/ added to PATH successfully."
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

# Function to set up Gobuster scripts and update PATH
setup_gobuster() {
    install_gobuster_scripts
    add_to_path_zsh
}

# Function to create a symbolic link for easy access (Optional)
create_symlinks() {
    echo "----------------------------------------"
    echo "Creating symbolic links for scripts (optional)..."
    echo "----------------------------------------"
    # This step is optional as /opt/djasper/ is already in PATH
    # But if desired, you can create symlinks in /usr/local/bin/
    # Example:
    # sudo ln -s /opt/djasper/feroxbuster_windows /usr/local/bin/feroxbuster_windows
    # sudo ln -s /opt/djasper/feroxbuster_linux /usr/local/bin/feroxbuster_linux
    # sudo ln -s /opt/djasper/gobuster_subdomains /usr/local/bin/gobuster_subdomains
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

    # Handle additional script setups based on choice
    case "$choice" in
        2)
            echo "Setting up Feroxbuster scripts and updating PATH..."
            setup_feroxbuster
            ;;
        3)
            echo "Setting up Gobuster scripts and updating PATH..."
            setup_gobuster
            ;;
        A|a)
            echo "Setting up Feroxbuster scripts and updating PATH..."
            setup_feroxbuster
            echo "Setting up Gobuster scripts and updating PATH..."
            setup_gobuster
            ;;
    esac

    echo "----------------------------------------"
    echo "Installation process completed."
    echo "----------------------------------------"
    echo "You can now use the following scripts from anywhere:"
    echo " - feroxbuster_windows <URL> [threads]"
    echo " - feroxbuster_linux <URL> [threads]"
    echo " - gobuster_subdomains <DOMAIN> [threads]"
    echo "----------------------------------------"
}

# Run the main function
main
