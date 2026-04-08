#!/bin/bash
#
# Barrier Auto Setup Script
# One-click setup for barrier-enhanced
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Barrier Enhanced - Auto Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root for system-wide installation
if [ "$EUID" -eq 0 ]; then
    INSTALL_DIR="/opt/barrier-enhanced"
    CONFIG_DIR="/etc/barrier"
    SYSTEM_WIDE=true
else
    INSTALL_DIR="$HOME/.local/barrier-enhanced"
    CONFIG_DIR="$HOME/.config/barrier"
    SYSTEM_WIDE=false
    echo -e "${YELLOW}Installing to user directory (not as root)${NC}"
fi

# Create directories
echo -e "\n${GREEN}[1/5] Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# Detect platform
PLATFORM=$(uname -s)
if [ "$PLATFORM" = "Linux" ]; then
    if [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO="$DISTRIB_DESCRIPTION"
    else
        DISTRO="Linux"
    fi
elif [ "$PLATFORM" = "Darwin" ]; then
    DISTRO="macOS"
else
    DISTRO="$PLATFORM"
fi
echo -e "Detected platform: ${GREEN}$DISTRO${NC}"

# Build from source if not already built
if [ ! -f "$INSTALL_DIR/bin/barrierg" ] && [ ! -f "$INSTALL_DIR/bin/barrier" ]; then
    echo -e "\n${GREEN}[2/5] Building from source...${NC}"

    # Install dependencies
    echo "Installing build dependencies..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y cmake make g++ \
            libavahi-compat-libdnssd-dev \
            libcurl4-openssl-dev \
            libssl-dev \
            libx11-dev \
            libxtst-dev \
            libxinerama-dev \
            libxrandr-dev \
            libxkbfile-dev \
            libxi-dev \
            qt5-default \
            qttools5-dev-tools \
            zlib1g-dev
    elif command -v brew &> /dev/null; then
        brew install cmake openssl
    fi

    # Build
    echo "Building barrier-enhanced..."
    cd "$(dirname "$0")/.."
    mkdir -p build
    cd build
    cmake .. -DBARRIER_BUILD_GUI=ON -DBARRIER_BUILD_TESTS=OFF
    make -j$(nproc)

    # Install
    echo "Installing..."
    cp -r bin "$INSTALL_DIR/"
    mkdir -p "$INSTALL_DIR/lib"
    cp -r lib/* "$INSTALL_DIR/lib/" 2>/dev/null || true

    cd ../..
    echo -e "${GREEN}Build complete!${NC}"
else
    echo -e "\n${GREEN}[2/5] Binary found, skipping build...${NC}"
fi

# Get local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)

echo -e "\n${GREEN}[3/5] Network Configuration${NC}"
echo -e "Your IP address: ${GREEN}$LOCAL_IP${NC}"
echo -e "Your hostname: ${GREEN}$HOSTNAME${NC}"

# Create default config
echo -e "\n${GREEN}[4/5] Creating configuration...${NC}"

read -p "Is this computer the [s]erver (has keyboard/mouse) or [c]lient? [s/c]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
    ROLE="server"
    read -p "Enter client hostname(s) [comma separated]: " CLIENTS
    read -p "Enter screen width (e.g., 1920): " SCREEN_W
    SCREEN_W=${SCREEN_W:-1920}
    read -p "Enter screen height (e.g., 1080): " SCREEN_H
    SCREEN_H=${SCREEN_H:-1080}

    cat > "$CONFIG_DIR/barrier.conf" << EOF
# Barrier Enhanced Configuration
# Server (primary screen with keyboard/mouse)

section: screens
    $HOSTNAME:
        $LOCAL_IP:$SCREEN_W,$SCREEN_H,0,0
$(for client in $(echo $CLIENTS | tr ',' ' '); do
    echo "    $client:"
    echo "        1.2.3.4:0,0,0"
done)

    # Options
    localShortcutMode = true
    lowLatencyMode = true
    clipboardSharing = true

end

section: aliases
$(for client in $(echo $CLIENTS | tr ',' ' '); do
    echo "    $client:"
    echo "        $client"
done)
end
EOF

elif [[ $REPLY =~ ^[Cc]$ ]]; then
    ROLE="client"
    read -p "Enter server IP address: " SERVER_IP
    read -p "Enter this client's hostname: " CLIENT_NAME
    CLIENT_NAME=${CLIENT_NAME:-$HOSTNAME}

    cat > "$CONFIG_DIR/barrier.conf" << EOF
# Barrier Enhanced Configuration
# Client (secondary screen)

section: screens
    $CLIENT_NAME:
        $SERVER_IP:24800

    # Options
    lowLatencyMode = true
    clipboardSharing = true

end
EOF
fi

echo -e "${GREEN}Configuration created at $CONFIG_DIR/barrier.conf${NC}"

# Create systemd service (Linux only)
if [ "$PLATFORM" = "Linux" ] && [ "$SYSTEM_WIDE" = true ]; then
    echo -e "\n${GREEN}[5/5] Setting up systemd service...${NC}"

    sudo tee /etc/systemd/system/barrier-enhanced.service > /dev/null << EOF
[Unit]
Description=Barrier Enhanced KVM
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/bin/barriers -c $CONFIG_DIR/barrier.conf
Restart=always
RestartSec=5
Environment="QT_QPA_PLATFORM=linuxfb"

# Performance optimizations
IOSchedulingClass=best-effort
CPUSchedulingPolicy=batch

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}Systemd service created!${NC}"
    echo -e "Run: ${YELLOW}sudo systemctl enable barrier-enhanced${NC}"
    echo -e "Run: ${YELLOW}sudo systemctl start barrier-enhanced${NC}"
fi

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "To start barrier:"
if [ "$ROLE" = "server" ]; then
    echo -e "  ${YELLOW}$INSTALL_DIR/bin/barriers -c $CONFIG_DIR/barrier.conf${NC}"
else
    echo -e "  ${YELLOW}$INSTALL_DIR/bin/barrierc -c $CONFIG_DIR/barrier.conf${NC}"
fi
echo ""
echo "Configuration file: $CONFIG_DIR/barrier.conf"
echo ""
