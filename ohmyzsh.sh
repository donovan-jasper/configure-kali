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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
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