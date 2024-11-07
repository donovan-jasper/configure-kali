#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
DJ_SAPER_DIR="/opt/djsaper"
BLOODHOUND_DIR="/opt/BloodHound"
ARSENAL_DIR="$DJ_SAPER_DIR/arsenal"
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

# Function to install or update Arsenal
install_or_update_arsenal() {
    echo "----------------------------------------"
    echo "Starting installation/update of Arsenal..."
    echo "----------------------------------------"

    if [ ! -d "$ARSENAL_DIR" ]; then
        echo "Cloning Arsenal repository to $ARSENAL_DIR..."
        sudo git clone https://github.com/Orange-Cyberdefense/arsenal.git "$ARSENAL_DIR"
    else
        echo "Arsenal directory exists. Pulling latest changes..."
        cd "$ARSENAL_DIR"
        sudo git pull
    fi

    # Navigate to the Arsenal directory
    cd "$ARSENAL_DIR"

    # Install Python dependencies
    echo "Installing Python dependencies for Arsenal..."
    sudo python3 -m pip install -r requirements.txt
    echo "Python dependencies installed successfully."

    # Navigate back to the original directory
    cd -

    # Add alias to .zshrc if not already present
    if grep -q "alias a='python3 $ARSENAL_DIR/run'" "$ZSHRC"; then
        echo "Alias 'a' for 'arsenal' already exists in $ZSHRC."
    else
        echo "Adding alias 'a' for 'arsenal' to $ZSHRC..."
        echo "alias a='python3 $ARSENAL_DIR/run'" | sudo tee -a "$ZSHRC" > /dev/null
        echo "Alias added successfully."
    fi

    # Reload zsh configuration
    echo "Reloading zsh configuration..."
    source "$ZSHRC"

    echo "----------------------------------------"
    echo "Arsenal has been installed/updated and is accessible via the 'a' alias."
    echo "----------------------------------------"
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
        local script_path="$DJ_SAPER_DIR/$script_name"
        local script_description="$2"
        local script_content="$3"

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
    if grep -q 'export PATH=.*\/opt/djsaper/' "$ZSHRC"; then
        echo "/opt/djsaper/ is already in your PATH."
    else
        echo "Adding /opt/djsaper/ to PATH in $ZSHRC..."
        echo 'export PATH="$PATH:/opt/djsaper/"' | sudo tee -a "$ZSHRC" > /dev/null
        echo "/opt/djsaper/ added to PATH successfully."
        echo "Reloading zsh configuration..."
        source "$ZSHRC"
    fi
}

# Function to install Arsenal via git clone
install_arsenal_git() {
    echo "----------------------------------------"
    echo "Starting installation of Arsenal..."
    echo "----------------------------------------"

    if [ ! -d "$ARSENAL_DIR" ]; then
        echo "Cloning Arsenal repository to $ARSENAL_DIR..."
        sudo git clone https://github.com/Orange-Cyberdefense/arsenal.git "$ARSENAL_DIR"
    else
        echo "Arsenal directory exists. Pulling latest changes..."
        cd "$ARSENAL_DIR"
        sudo git pull
        cd -
    fi

    # Navigate to the Arsenal directory
    cd "$ARSENAL_DIR"

    # Install Python dependencies
    echo "Installing Python dependencies for Arsenal..."
    sudo python3 -m pip install -r requirements.txt
    echo "Python dependencies installed successfully."

    # Add alias to .zshrc if not already present
    if grep -q "alias a='python3 $ARSENAL_DIR/run'" "$ZSHRC"; then
        echo "Alias 'a' for 'arsenal' already exists in $ZSHRC."
    else
        echo "Adding alias 'a' for 'arsenal' to $ZSHRC..."
        echo "alias a='python3 $ARSENAL_DIR/run'" | sudo tee -a "$ZSHRC" > /dev/null
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
install_option4() {
    echo "----------------------------------------"
    echo "Option 4 is not implemented yet."
    echo "----------------------------------------"
}

# Function to display the menu and get user selection
show_menu() {
    echo "----------------------------------------"
    echo "Please select an option:"
    echo "1. Update Installed Tools"
    echo "2. Install BloodHound"
    echo "3. Install Feroxbuster"
    echo "4. Install Arsenal"
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
            update_and_install_packages
            install_or_update_bloodhound
            install_or_update_arsenal
            echo "----------------------------------------"
            echo "Tools have been updated successfully."
            echo "----------------------------------------"
            ;;
        2)
            install_or_update_bloodhound
            ;;
        3)
            install_feroxbuster_scripts
            ;;
        4)
            install_or_update_arsenal
            ;;
        A|a)
            echo "Installing all tools..."
            update_and_install_packages
            install_or_update_bloodhound
            install_feroxbuster_scripts
            install_or_update_arsenal
            echo "----------------------------------------"
            echo "All tools have been installed successfully."
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
    echo "If you installed Arsenal, you can launch it using the 'a' alias:"
    echo " - a"
    echo "----------------------------------------"
}

# Run the main function
main
