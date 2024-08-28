# Clone the Powerlevel10k theme into the custom themes directory
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
else
    echo "Powerlevel10k is already installed"
fi

# Configure .zshrc to use Powerlevel10k theme
echo "Configuring .zshrc to use Powerlevel10k theme..."
curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/templates/zshrc.zsh-template -o "$HOME/.zshrc"
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' "$HOME/.zshrc"

# Install recommended fonts for Powerlevel10k
echo "Installing recommended fonts for Powerlevel10k..."
git clone https://github.com/romkatv/powerlevel10k-media.git $HOME/.powerlevel10k-media
$HOME/.powerlevel10k-media/install-fonts.sh

# Restart Zsh to apply the new configuration
echo "Restarting Zsh..."
exec zsh
