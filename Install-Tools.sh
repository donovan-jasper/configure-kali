#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
DJ_SAPER_DIR="/opt/djasper"
WORDLIST_DIR="/usr/share/seclists/Discovery"
DIRECTORY_WORDLIST="$WORDLIST_DIR/Web-Content/directory-list-2.3-medium.txt"
SUBDOMAIN_WORDLIST="$WORDLIST_DIR/DNS/subdomains-top1million-110000.txt"
VHOST_WORDLIST="$WORDLIST_DIR/Web-Content/best-vhosts.txt"  # Example wordlist for vhost
ZSHRC="$HOME/.zshrc"

# Function to update package list and install necessary packages
update_and_install_packages() {
    echo "----------------------------------------"
    echo "Updating package list and installing dependencies..."
    echo "----------------------------------------"
    sudo apt update -y
    sudo apt install -y docker-compose git feroxbuster gobuster seclists xclip
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
            -w "'"$DIRECTORY_WORDLIST"'" \
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
            -w "'"$DIRECTORY_WORDLIST"'" \
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

    # Define gobuster_dns script content with optional -r flag
    GOBUSTER_DNS_CONTENT='#!/bin/bash

# Script: gobuster_dns
# Description: Runs Gobuster for DNS subdomain enumeration with optional recursion.

# Check if at least one argument (DOMAIN) is provided
if [ -z "$1" ]; then
    echo "Usage: gobuster_dns <DOMAIN> [threads] [--recursive]"
    exit 1
fi

DOMAIN="$1"
THREADS="${2:-100}"  # Default to 100 threads if not specified
RECURSIVE=false

# Check for --recursive flag
if [[ "$3" == "--recursive" ]]; then
    RECURSIVE=true
fi

# Construct Gobuster command
CMD="gobuster dns -d \"$DOMAIN\" -w \"$SUBDOMAIN_WORDLIST\" -t \"$THREADS\""

if [ "$RECURSIVE" = true ]; then
    CMD+=" -r"
fi

# Execute Gobuster
eval $CMD
'

    # Define gobuster_vhost script content
    GOBUSTER_VHOST_CONTENT='#!/bin/bash

# Script: gobuster_vhost
# Description: Runs Gobuster for Virtual Host enumeration.

# Check if at least one argument (URL) is provided
if [ -z "$1" ]; then
    echo "Usage: gobuster_vhost <URL> [threads]"
    exit 1
fi

URL="$1"
THREADS="${2:-100}"  # Default to 100 threads if not specified

# Ensure the URL starts with http:// or https://
if [[ "$URL" != http://* && "$URL" != https://* ]]; then
    echo "Error: URL must start with http:// or https://"
    exit 1
fi

# Example wordlist for vhost enumeration (ensure this exists or adjust the path)
VHOST_WORDLIST="'$VHOST_WORDLIST'"

# Check if the VHOST_WORDLIST exists
if [ ! -f "$VHOST_WORDLIST" ]; then
    echo "Error: VHOST wordlist not found at $VHOST_WORDLIST"
    exit 1
fi

# Run Gobuster for virtual hosts
gobuster vhost -u "$URL" -w "$VHOST_WORDLIST" -t "$THREADS"
'

    # Create gobuster_dns
    echo "Creating gobuster_dns..."
    echo "$GOBUSTER_DNS_CONTENT" | sudo tee "$DJ_SAPER_DIR/gobuster_dns" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/gobuster_dns"

    # Create gobuster_vhost
    echo "Creating gobuster_vhost..."
    echo "$GOBUSTER_VHOST_CONTENT" | sudo tee "$DJ_SAPER_DIR/gobuster_vhost" > /dev/null
    sudo chmod +x "$DJ_SAPER_DIR/gobuster_vhost"

    echo "----------------------------------------"
    echo "Gobuster scripts created successfully in $DJ_SAPER_DIR."
    echo "----------------------------------------"
}

# Placeholder functions for options beyond 4
install_option5() {
    echo "----------------------------------------"
    echo "Option 5 is not implemented yet."
    echo "----------------------------------------"
}

# Function to display the menu and get user selection
show_menu() {
    echo "----------------------------------------"
    echo "Please select an option to perform:"
    echo "1. Update and Install Dependencies"
    echo "2. Install BloodHound"
    echo "3. Install Feroxbuster"
    echo "4. Install Gobuster"
    echo "A. Install All of the Above"
    echo "----------------------------------------"
    echo -n "Enter your choice (1-4 or A): "
    read -r choice
}

# Function to handle the user's selection
handle_selection() {
    case "$choice" in
        1)
            update_and_install_packages
            ;;
        2)
            install_bloodhound
            ;;
        3)
            install_feroxbuster_scripts
            ;;
        4)
            install_gobuster_scripts
            ;;
        A|a)
            install_bloodhound
            install_feroxbuster_scripts
            install_gobuster_scripts
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
        # Append the export PATH line to .zshrc
        echo 'export PATH="$PATH:/opt/djasper/"' | sudo tee -a "$ZSHRC" > /dev/null
        echo "/opt/djasper/ added to PATH successfully."

        # Copy the export PATH line to clipboard
        echo 'export PATH="$PATH:/opt/djasper/"' | xclip -selection clipboard
        echo "The PATH update command has been copied to your clipboard."
        echo "Please paste it into your terminal or restart your terminal session to apply the changes."
    fi
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
    # sudo ln -s /opt/djasper/gobuster_dns /usr/local/bin/gobuster_dns
    # sudo ln -s /opt/djasper/gobuster_vhost /usr/local/bin/gobuster_vhost
    echo "Symbolic links creation is optional and not performed by this script."
    echo "You can manually create symlinks if needed."
}

# Main script execution
main() {
    echo "========================================"
    echo "Welcome to the Tool Installation Script"
    echo "========================================"

    show_menu
    handle_selection

    # Handle additional script setups based on choice
    case "$choice" in
        2)
            echo "BloodHound setup completed."
            ;;
        3)
            echo "Setting up Feroxbuster scripts and updating PATH..."
            setup_feroxbuster
            ;;
        4)
            echo "Setting up Gobuster scripts and updating PATH..."
            setup_gobuster
            ;;
        A|a)
            echo "BloodHound setup completed."
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
    echo " - gobuster_dns <DOMAIN> [threads] [--recursive]"
    echo " - gobuster_vhost <URL> [threads]"
    echo "----------------------------------------"
    echo "Remember to paste the PATH update command from your clipboard into your terminal or restart your terminal session."
}

# Run the main function
main
