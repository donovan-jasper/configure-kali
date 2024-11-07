#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
DJ_SAPER_DIR="/opt/djsaper"
BLOODHOUND_DIR="/opt/BloodHound"
WORDLIST_DIR="/usr/share/seclists/Discovery"
DIRECTORY_WORDLIST="$WORDLIST_DIR/Web-Content/directory-list-2.3-medium.txt"
SUBDOMAIN_WORDLIST="$WORDLIST_DIR/DNS/subdomains-top1million-110000.txt"
ZSHRC="$HOME/.zshrc"
USER_NAME="${SUDO_USER:-$(whoami)}"

# Function to update package list and install necessary packages
update_and_install_packages() {
    echo "----------------------------------------"
    echo "Updating package list and installing dependencies..."
    echo "----------------------------------------"
    sudo apt update -y
    sudo apt install -y docker-compose git gobuster feroxbuster seclists python3-pip
    echo "----------------------------------------"
    echo "Package installation completed."
    echo "----------------------------------------"
}

# Function to install or update BloodHound
install_or_update_bloodhound() {
    echo "----------------------------------------"
    echo "Starting installation/update of BloodHound..."
    echo "----------------------------------------"

    if [ ! -d "$BLOODHOUND_DIR" ]; then
        echo "Cloning BloodHound repository to $BLOODHOUND_DIR..."
        sudo git clone https://github.com/SpecterOps/BloodHound.git "$BLOODHOUND_DIR"
    else
        echo "BloodHound directory exists. Pulling latest changes..."
        cd "$BLOODHOUND_DIR"
        sudo git pull
    fi

    # Navigate to the BloodHound directory
    cd "$BLOODHOUND_DIR"

    # Copy Docker Compose example files if they don't exist
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
        echo "BloodHound has been installed/updated successfully."
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

    # Function to create a script using here-doc
    create_script() {
        local script_name="$1"
        local script_description="$2"
        local script_content="$3"
        local script_path="$DJ_SAPER_DIR/$script_name"

        if [ -f "$script_path" ]; then
            echo "$script_name already exists. Skipping creation."
        else
            echo "Creating $script_name..."
            sudo tee "$script_path" > /dev/null <<EOL
#!/bin/bash

# Script: $script_name
# Description: $script_description

# Check if at least one argument (URL or DOMAIN) is provided
if [ -z "\$1" ]; then
    echo "Usage: $script_name <URL|DOMAIN> [threads]"
    exit 1
fi

INPUT="\$1"
THREADS="\${2:-100}"  # Default to 100 threads if not specified

$script_content
EOL
            sudo chmod +x "$script_path"
            echo "$script_name created and made executable."
        fi
    }

    # Define script contents without quotes for variables
    DIR_WINDOWS_CMD='feroxbuster --url "$INPUT" \
    -r \
    -t "$THREADS" \
    -w '"$DIRECTORY_WORDLIST"' \
    -C 404,403,400,503,500,501,502 \
    -x exe,bat,msi,cmd,ps1 \
    --dont-scan "vendor,fonts,images,css,assets,docs,js,static,img,help"'

    DIR_LINUX_CMD='feroxbuster --url "$INPUT" \
    -r \
    -t "$THREADS" \
    -w '"$DIRECTORY_WORDLIST"' \
    -C 404,403,400,503,500,501,502 \
    -x txt,sh,zip,bak,py,php \
    --dont-scan "vendor,fonts,images,css,assets,docs,js,static,img,help"'

    SUBDOMAIN_CMD='feroxbuster --domain "$INPUT" \
    -r \
    -t "$THREADS" \
    -w '"$SUBDOMAIN_WORDLIST"' \
    --subdomains \
    --silent'

    # Create feroxbuster_windows.sh
    create_script "feroxbuster_windows.sh" "Runs feroxbuster with Windows-specific flags for directory enumeration." "$DIR_WINDOWS_CMD"

    # Create feroxbuster_linux.sh
    create_script "feroxbuster_linux.sh" "Runs feroxbuster with Linux-specific flags for directory enumeration." "$DIR_LINUX_CMD"

    # Create feroxbuster_subdomain.sh
    create_script "feroxbuster_subdomain.sh" "Runs feroxbuster for subdomain enumeration." "$SUBDOMAIN_CMD"

    echo "----------------------------------------"
    echo "Feroxbuster scripts set up successfully in $DJ_SAPER_DIR."
    echo "----------------------------------------"

    # Add /opt/djsaper/ to PATH in zsh if not already present
    if sudo -u "$USER_NAME" grep -q 'export PATH=.*\/opt/djsaper/' "$ZSHRC"; then
        echo "/opt/djsaper/ is already in your PATH."
    else
        echo "Adding /opt/djsaper/ to PATH in $ZSHRC..."
        echo 'export PATH="$PATH:/opt/djsaper/"' | sudo tee -a "$ZSHRC" > /dev/null
        echo "/opt/djsaper/ added to PATH successfully."
        echo "Reloading zsh configuration..."
        sudo -u "$USER_NAME" bash -c "source '$ZSHRC'"
    fi
}

# Function to install Gobuster scripts
install_gobuster_scripts() {
    echo "----------------------------------------"
    echo "Setting up Gobuster scripts in $DJ_SAPER_DIR..."
    echo "----------------------------------------"

    # Ensure Gobuster is installed
    if ! command -v gobuster &> /dev/null; then
        echo "Gobuster is not installed. Installing..."
        sudo apt install -y gobuster
    else
        echo "Gobuster is already installed."
    fi

    # Function to create a script using here-doc
    create_script() {
        local script_name="$1"
        local script_description="$2"
        local script_content="$3"
        local script_path="$DJ_SAPER_DIR/$script_name"

        if [ -f "$script_path" ]; then
            echo "$script_name already exists. Skipping creation."
        else
            echo "Creating $script_name..."
            sudo tee "$script_path" > /dev/null <<EOL
#!/bin/bash

# Script: $script_name
# Description: $script_description

# Check if at least one argument (DOMAIN) is provided
if [ -z "\$1" ]; then
    echo "Usage: $script_name <DOMAIN> [threads]"
    exit 1
fi

DOMAIN="\$1"
THREADS="\${2:-100}"  # Default to 100 threads if not specified

$script_content
EOL
            sudo chmod +x "$script_path"
            echo "$script_name created and made executable."
        fi
    }

    # Define script contents without quotes for variables
    DNS_ENUM_CMD='gobuster dns -d "$DOMAIN" \
    -t "$THREADS" \
    -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt \
    -o "$DJ_SAPER_DIR/gobuster_dns_output.txt"'

    VHOST_ENUM_CMD='gobuster vhost -u http://"$DOMAIN" \
    -t "$THREADS" \
    -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt \
    -o "$DJ_SAPER_DIR/gobuster_vhost_output.txt"'

    # Create gobuster_dns.sh
    create_script "gobuster_dns.sh" "Runs Gobuster for DNS subdomain enumeration." "$DNS_ENUM_CMD"

    # Create gobuster_vhost.sh
    create_script "gobuster_vhost.sh" "Runs Gobuster for Virtual Host enumeration." "$VHOST_ENUM_CMD"

    echo "----------------------------------------"
    echo "Gobuster scripts set up successfully in $DJ_SAPER_DIR."
    echo "----------------------------------------"

    # Add /opt/djsaper/ to PATH in zsh if not already present (already handled in Feroxbuster section)
}

# Function to update installed tools
update_tools() {
    echo "----------------------------------------"
    echo "Updating installed tools..."
    echo "----------------------------------------"
    update_and_install_packages

    # Update BloodHound
    if [ -d "$BLOODHOUND_DIR" ]; then
        install_or_update_bloodhound
    else
        echo "BloodHound is not installed. Skipping update."
    fi

    # Update Feroxbuster scripts
    if [ -d "$DJ_SAPER_DIR" ]; then
        echo "Updating Feroxbuster scripts..."
        install_feroxbuster_scripts
        install_gobuster_scripts
    else
        echo "Feroxbuster scripts are not installed. Skipping update."
    fi

    echo "----------------------------------------"
    echo "Update process completed."
    echo "----------------------------------------"
}

# Function to display the menu and get user selection
show_menu() {
    echo "----------------------------------------"
    echo "Please select an option:"
    echo "1. Update Installed Tools"
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
            echo "Updating installed tools..."
            update_tools
            ;;
        2)
            install_or_update_bloodhound
            ;;
        3)
            install_feroxbuster_scripts
            install_gobuster_scripts
            ;;
        4)
            install_gobuster_scripts
            ;;
        A|a)
            echo "Installing all tools..."
            update_and_install_packages
            install_or_update_bloodhound
            install_feroxbuster_scripts
            install_gobuster_scripts
            echo "----------------------------------------"
            echo "All tools have been installed/updated successfully."
            echo "----------------------------------------"
            ;;
        *)
            echo "----------------------------------------"
            echo "Invalid selection. Please run the script again and choose a valid option."
            echo "----------------------------------------"
            exit 1
            ;;
    esac
}

# Main script execution
main() {
    echo "========================================"
    echo "Welcome to the Tool Installation Script"
    echo "========================================"

    show_menu
    handle_selection

    echo "----------------------------------------"
    echo "Installation process completed."
    echo "----------------------------------------"
    echo "If you installed Feroxbuster, you can now use the following scripts from anywhere:"
    echo " - feroxbuster_windows.sh <URL> [threads]"
    echo " - feroxbuster_linux.sh <URL> [threads]"
    echo " - feroxbuster_subdomain.sh <DOMAIN> [threads]"
    echo "----------------------------------------"
    echo "If you installed Gobuster, you can now use the following scripts from anywhere:"
    echo " - gobuster_dns.sh <DOMAIN> [threads]"
    echo " - gobuster_vhost.sh <DOMAIN> [threads]"
    echo "----------------------------------------"
    echo "To use Feroxbuster and Gobuster scripts without specifying the full path, ensure /opt/djsaper/ is in your PATH."
    echo "----------------------------------------"
}

# Run the main function
main
