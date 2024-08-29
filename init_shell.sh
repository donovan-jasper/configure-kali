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

# Start a new Zsh shell
exec zsh
