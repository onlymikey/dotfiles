#!/usr/bin/env bash

set -e

# Change directory to the repository root
cd "$(dirname "$0")"

# Check if running on Arch Linux
if [[ ! -f /etc/arch-release ]]; then
  echo "Error: This installer officially supports Arch Linux only ('btw')."
  exit 1
fi

# Packages lists
PACKAGES_REQUIRED=(
  "hyprland"
  "hyprlock"
  "hypridle"
  "kitty"
  "thunar"
  "python"
  "networkmanager"
  "bluez"
  "bluez-utils"
  "wireplumber"
  "brightnessctl"
  "playerctl"
  "imagemagick"
  "socat"
  "inotify-tools"
  "ttf-jetbrains-mono"
  "ttf-jetbrains-mono-nerd"
  "quickshell"
)

PACKAGES_OPTIONAL=(
  "python-pywal"
  "wl-clipboard"
  "cliphist"
  "awww"
  "cava"
  "fastfetch"
  "starship"
  "grim"
  "slurp"
  "rmpc"
  "gpu-screen-recorder"
)

AUR_REQUIRED=()
AUR_OPTIONAL=()

# Helper functions
echo_step() {
  echo -e "\n\033[1;34m==>\033[0m \033[1;37m$1\033[0m"
}

echo_success() {
  echo -e "\033[1;32m✓\033[0m $1"
}

echo_warning() {
  echo -e "\033[1;33m⚠\033[0m $1"
}

echo_error() {
  echo -e "\033[1;31m✗\033[0m $1"
}

detect_aur_helper() {
  if command -v yay &>/dev/null; then
    echo "yay"
  elif command -v paru &>/dev/null; then
    echo "paru"
  else
    echo ""
  fi
}

install_dependencies() {
  echo_step "Detecting dependencies..."
  
  # 1. Install official repository packages
  echo "Installing required and optional official packages..."
  sudo pacman -S --needed "${PACKAGES_REQUIRED[@]}" "${PACKAGES_OPTIONAL[@]}" || {
    echo_error "Failed to install official repository packages."
    exit 1
  }

  # 2. Detect AUR helper
  local helper=$(detect_aur_helper)
  if [[ -n "$helper" ]]; then
    echo_success "Found AUR helper: $helper"
    echo "Installing AUR packages: ${AUR_REQUIRED[*]} ${AUR_OPTIONAL[*]}"
    $helper -S --needed "${AUR_REQUIRED[@]}" "${AUR_OPTIONAL[@]}" || {
      echo_warning "Some AUR packages failed to install. Please check them manually."
    }
  else
    echo_warning "No AUR helper (yay/paru) detected!"
    echo "Please install an AUR helper or manually build/install the following:"
    echo "Required: ${AUR_REQUIRED[*]}"
    echo "Optional: ${AUR_OPTIONAL[*]}"
  fi

  # 3. Enable standard services
  echo "Enabling standard system services..."
  sudo systemctl enable --now NetworkManager 2>/dev/null || true
  sudo systemctl enable --now bluetooth 2>/dev/null || true
}

backup_config() {
  local target_dir="$1"
  if [[ -e "$target_dir" ]]; then
    local name=$(basename "$target_dir")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${target_dir}.backup-${timestamp}"
    echo "Safe backup: Moving existing $name to $backup_path"
    mv "$target_dir" "$backup_path"
  fi
}

deploy_configurations() {
  echo_step "Deploying configurations..."
  mkdir -p ~/.config ~/wallpapers

  # Safe backups of the main components
  backup_config ~/.config/hypr
  backup_config ~/.config/quickshell
  backup_config ~/.config/kitty
  backup_config ~/.config/fastfetch
  backup_config ~/.config/cava
  backup_config ~/.config/swaync
  backup_config ~/.config/scripts
  backup_config ~/.config/wal
  backup_config ~/.config/templates
  backup_config ~/.config/Thunar
  backup_config ~/.config/qt5ct
  backup_config ~/.config/qt6ct

  # Copy configurations from the repository
  cp -r .config/hypr ~/.config/
  cp -r .config/quickshell ~/.config/
  cp -r .config/kitty ~/.config/
  cp -r .config/fastfetch ~/.config/
  cp -r .config/cava ~/.config/
  cp -r .config/scripts ~/.config/
  cp -r .config/wal ~/.config/
  cp -r .config/templates ~/.config/
  cp -r .config/qt5ct ~/.config/
  cp -r .config/qt6ct ~/.config/

  if [[ -f .config/starship.toml ]]; then
    backup_config ~/.config/starship.toml
    cp .config/starship.toml ~/.config/
  fi

  # Deploy wallpapers
  if [[ -d wallpapers ]]; then
    cp -n wallpapers/* ~/wallpapers/ 2>/dev/null || true
  fi

  # Use the versioned start helper script from ~/.config/scripts
  chmod +x ~/.config/scripts/start-quickshell.sh 2>/dev/null || true

  # Ensure scripts and helper scripts are executable
  chmod +x ~/.config/scripts/* 2>/dev/null || true
  chmod +x ~/.config/quickshell/services/*.py 2>/dev/null || true

  echo_success "Configurations deployed."
}

configure_optional_services() {
  echo_step "Optional services deployment..."
  
  if [[ -f ~/.config/quickshell/systemd/quickshell-session.service ]]; then
    echo "Would you like to install the optional Session Restore systemd --user service?"
    echo "This service automatically captures your window layout on shutdown or logout,"
    echo "allowing automatic layout restore during next login."
    read -p "Install Session Restore service? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      mkdir -p ~/.config/systemd/user
      cp ~/.config/quickshell/systemd/quickshell-session.service ~/.config/systemd/user/
      systemctl --user daemon-reload
      systemctl --user enable --now quickshell-session.service
      echo_success "Session Restore systemd service installed and enabled successfully."
    else
      echo "Skipped systemd service installation. You can install it later from the Dashboard."
    fi
  else
    echo_warning "Session Restore systemd template not found. Skipping."
  fi
}

validate_installation() {
  echo_step "Validating installation state..."
  local errors=0
  local warnings=0

  # Check configurations
  if [[ -f ~/.config/hypr/hyprland.lua ]]; then
    echo_success "Hyprland configuration: Installed"
  else
    echo_error "Hyprland configuration: Missing"
    errors=$((errors+1))
  fi

  if [[ -f ~/.config/quickshell/shell.qml ]]; then
    echo_success "Quickshell configuration: Installed"
  else
    echo_error "Quickshell configuration: Missing"
    errors=$((errors+1))
  fi

  if [[ -x ~/.config/quickshell/services/session_helper.py ]]; then
    echo_success "Python helper scripts: Installed & Executable"
  else
    echo_error "Python helper scripts: Missing or not executable"
    errors=$((errors+1))
  fi

  if [[ -f ~/.config/hypr/monitors.lua ]]; then
    echo_success "Monitor configuration: Separated (monitors.lua)"
  else
    echo_error "Monitor configuration: Missing monitors.lua"
    errors=$((errors+1))
  fi

  # Check dependencies
  for pkg in "${PACKAGES_REQUIRED[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
      :
    else
      echo_error "Required dependency missing: $pkg"
      errors=$((errors+1))
    fi
  done

  # Check AUR required dependencies
  if pacman -Qi quickshell &>/dev/null || pacman -Qi quickshell-git &>/dev/null; then
    :
  else
    echo_error "Required dependency missing: quickshell (or quickshell-git)"
    errors=$((errors+1))
  fi

  # Check optional dependencies
  for pkg in "${PACKAGES_OPTIONAL[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
      :
    else
      echo_warning "Optional dependency not found: $pkg"
      warnings=$((warnings+1))
    fi
  done

  # Check systemd user service status
  if systemctl --user is-enabled quickshell-session.service &>/dev/null; then
    echo_success "Session Restore systemd service: Active & Enabled"
  else
    echo_warning "Session Restore systemd service: Not active or not installed"
    warnings=$((warnings+1))
  fi

  # Installation summary
  echo -e "\n========================================="
  echo "         INSTALLATION SUMMARY"
  echo "========================================="
  if [[ $errors -eq 0 ]]; then
    echo_success "All required components are installed correctly!"
    if [[ $warnings -gt 0 ]]; then
      echo "Note: There are $warnings optional components/dependencies missing."
    fi
    echo -e "\nInstallation completed successfully."
    echo "Please log out of your session and log back in to load Hyprland + Quickshell."
    echo "Enjoy your new rice! :)"
  else
    echo_error "Installation finished with $errors errors and $warnings warnings."
    echo "Please review the log messages above to fix any missing components."
  fi
  echo "========================================="
}

# Main installer execution flow
echo "========================================="
echo "  Hyprland & Quickshell Rice Installer"
echo "========================================="

read -p "Would you like to install packages and dependencies? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  install_dependencies
fi

read -p "Would you like to deploy/update configurations (with safe backups)? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  deploy_configurations
  configure_optional_services
fi

validate_installation