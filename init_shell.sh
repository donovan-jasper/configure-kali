#!/bin/bash

# Update package list and install zsh if it's not installed
if ! command -v zsh &> /dev/null
then
    echo "zsh not found, installing..."
    sudo apt-get update && sudo apt-get install zsh -y
fi

# Install Oh My Zsh if it's not installed
if [ ! -d "$HOME/.oh-my-zsh" ]
then
    echo "Oh My Zsh not found, installing..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh is already installed"
fi

# Set Zsh as the default shell if it's not already
if [ "$SHELL" != "$(which zsh)" ]
then
    echo "Changing default shell to zsh..."
    chsh -s $(which zsh)
fi

# Backup existing .zshrc file if it exists
if [ -f "$HOME/.zshrc" ]
then
    echo "Backing up existing .zshrc file..."
    mv "$HOME/.zshrc" "$HOME/.zshrc.backup_$(date +%Y%m%d_%H%M%S)"
fi

# Backup existing .p10k.zsh file if it exists
if [ -f "$HOME/.p10k.zsh" ]
then
    echo "Backing up existing .p10k.zsh file..."
    mv "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.backup_$(date +%Y%m%d_%H%M%S)"
fi

# Copy the custom .zshrc and .p10k.zsh files to the home directory
echo "Copying custom .zshrc and .p10k.zsh files..."
cp .zshrc $HOME/.zshrc
cp .p10k.zsh $HOME/.p10k.zsh

# Clone the Powerlevel10k theme into the custom themes directory (if not already installed)
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
else
    echo "Powerlevel10k is already installed"
fi

# Clone the zsh-syntax-highlighting plugin
if [ ! -d "$HOME/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting is already installed"
fi

# Add zsh-syntax-highlighting to the end of .zshrc
echo "source $HOME/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> $HOME/.zshrc

# Ensure the logs directory exists
echo "Ensuring ~/logs directory exists..."
mkdir -p ~/logs

# Define the script to be run on shell startup
# Replace 'your_script.sh' with the actual script you want to run
STARTUP_SCRIPT_PATH="$HOME/your_script.sh"

# Ensure the startup script exists and is executable
if [ ! -f "$STARTUP_SCRIPT_PATH" ]; then
    echo "Startup script not found at $STARTUP_SCRIPT_PATH. Please create it or update the path."
else
    chmod +x "$STARTUP_SCRIPT_PATH"
fi

# Add function to .zshrc to run the startup script and log output
echo "Adding startup script execution to .zshrc..."

cat << 'EOF' >> $HOME/.zshrc

# Function to run a startup script and log its output
run_startup_script() {
    local log_dir="$HOME/logs"
    mkdir -p "$log_dir"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$log_dir/log-$timestamp.log"
    
    # Replace the path below with the path to your actual script
    "$HOME/your_script.sh" > "$log_file" 2>&1
}

# Execute the startup script function
run_startup_script
EOF

# Start a new Zsh shell
exec zsh
