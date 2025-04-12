#!/bin/bash
# filepath: install_sniproxy.sh

# Script to install sniproxy directly on a Linux system (Debian/Ubuntu focus)

# --- Configuration ---
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/sniproxy"
SERVICE_NAME="sniproxy"
SNIPROXY_USER="sniproxy" # User to run sniproxy as (will be created if not exists)
# --- End Configuration ---

# --- Colors ---
GREEN='\033[0;32m'
NC='\033[0m' # No Color
# --- End Colors ---

set -e # Exit immediately if a command exits with a non-zero status.

# --- Check Root ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (or using sudo)." # Keep as is (error/instruction)
   exit 1
fi

# --- Check Dependencies ---
echo -e "${GREEN}[INFO] Checking dependencies...${NC}"
command -v wget >/dev/null 2>&1 || { echo >&2 "wget is required but it's not installed. Please install it (e.g., 'sudo apt update && sudo apt install wget'). Aborting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but it's not installed. Please install it (e.g., 'sudo apt update && sudo apt install jq'). Aborting."; exit 1; }
command -v tar >/dev/null 2>&1 || { echo >&2 "tar is required but it's not installed. Please install it (e.g., 'sudo apt update && sudo apt install tar'). Aborting."; exit 1; }
command -v systemctl >/dev/null 2>&1 || { echo >&2 "systemd (systemctl) is required. This script might not work on non-systemd systems. Aborting."; exit 1; }
echo -e "${GREEN}[INFO] Dependencies found.${NC}"

# --- Check for existing config/binary ---
if [ -f "${INSTALL_DIR}/sniproxy" ] || [ -d "${CONFIG_DIR}" ] || systemctl is-active --quiet ${SERVICE_NAME}; then
    # Prompt remains default color
    read -p "sniproxy seems to be already installed or configured. Overwrite? (y/N): " -n 1 -r
    echo # Move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}[INFO] Aborting installation.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[INFO] Proceeding with overwrite...${NC}"
    # Attempt to stop the service if it's running
    systemctl stop ${SERVICE_NAME} >/dev/null 2>&1 || true
    systemctl disable ${SERVICE_NAME} >/dev/null 2>&1 || true
fi


# --- Create User ---
echo -e "${GREEN}[INFO] Creating user '${SNIPROXY_USER}'...${NC}"
if id "${SNIPROXY_USER}" &>/dev/null; then
    echo -e "${GREEN}[INFO] User '${SNIPROXY_USER}' already exists.${NC}"
else
    useradd --system --no-create-home --shell /usr/sbin/nologin ${SNIPROXY_USER}
    echo -e "${GREEN}[INFO] User '${SNIPROXY_USER}' created.${NC}"
fi

# --- Download sniproxy ---
echo -e "${GREEN}[INFO] Downloading latest sniproxy release for linux-amd64...${NC}"
LATEST_URL=$(wget -qO- https://api.github.com/repos/mosajjal/sniproxy/releases/latest | jq -r '.assets[] | select(.name | endswith("linux-amd64.tar.gz")) | .browser_download_url')

if [ -z "${LATEST_URL}" ] || [ "${LATEST_URL}" == "null" ]; then
    echo >&2 "Could not determine the latest download URL. Aborting." # Keep as is (error)
    exit 1
fi

echo -e "${GREEN}[INFO] Downloading from ${LATEST_URL}${NC}"
TEMP_DIR=$(mktemp -d)
# Make wget less verbose or redirect its output if desired
wget -q --show-progress -O "${TEMP_DIR}/sniproxy.tar.gz" "${LATEST_URL}"

# --- Extract and Install Binary ---
echo -e "${GREEN}[INFO] Extracting and installing sniproxy binary to ${INSTALL_DIR}...${NC}"
tar -xzf "${TEMP_DIR}/sniproxy.tar.gz" -C "${TEMP_DIR}"
install -m 755 "${TEMP_DIR}/sniproxy" "${INSTALL_DIR}/sniproxy"
echo -e "${GREEN}[INFO] sniproxy installed.${NC}"

# --- Setup Configuration ---
echo -e "${GREEN}[INFO] Setting up configuration in ${CONFIG_DIR}...${NC}"
SCRIPT_DIR=$(dirname "$(readlink -f "$0")") # Get directory where the script is located

if [ ! -f "${SCRIPT_DIR}/config.yaml" ]; then
    echo >&2 "Error: config.yaml not found in the script directory (${SCRIPT_DIR}). Aborting." # Keep as is (error)
    rm -rf "${TEMP_DIR}"
    exit 1
fi
if [ ! -f "${SCRIPT_DIR}/domains.csv" ]; then
    echo >&2 "Error: domains.csv not found in the script directory (${SCRIPT_DIR}). Aborting." # Keep as is (error)
    rm -rf "${TEMP_DIR}"
    exit 1
fi

mkdir -p "${CONFIG_DIR}"
cp "${SCRIPT_DIR}/config.yaml" "${CONFIG_DIR}/config.yaml"
cp "${SCRIPT_DIR}/domains.csv" "${CONFIG_DIR}/domains.csv" # Copy domains list

sed -i 's|path:.*|path: /etc/sniproxy/domains.csv|' "${CONFIG_DIR}/config.yaml"

chown -R "${SNIPROXY_USER}:${SNIPROXY_USER}" "${CONFIG_DIR}"
chmod 644 "${CONFIG_DIR}/config.yaml"
chmod 644 "${CONFIG_DIR}/domains.csv"
echo -e "${GREEN}[INFO] Configuration files copied.${NC}"

# --- Create systemd Service File ---
echo -e "${GREEN}[INFO] Creating systemd service file...${NC}"
cat << EOF > /etc/systemd/system/${SERVICE_NAME}.service
[Unit]
Description=SNI Proxy Service
After=network.target

[Service]
User=${SNIPROXY_USER}
Group=${SNIPROXY_USER}
WorkingDirectory=/tmp
ExecStart=${INSTALL_DIR}/sniproxy --config ${CONFIG_DIR}/config.yaml
Restart=on-failure
RestartSec=5s
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/${SERVICE_NAME}.service
echo -e "${GREEN}[INFO] Systemd service file created.${NC}"

# --- Enable and Start Service ---
echo -e "${GREEN}[INFO] Reloading systemd daemon, enabling and starting ${SERVICE_NAME} service...${NC}"
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# --- Cleanup ---
rm -rf "${TEMP_DIR}"
echo -e "${GREEN}[INFO] Cleaning up temporary files.${NC}"

# --- Final Status and Notes ---
echo "" # Keep as is (formatting)
# systemctl status output will have its own colors
systemctl status ${SERVICE_NAME} --no-pager
echo "" # Keep as is (formatting)
echo -e "${GREEN}[INFO] sniproxy installation complete and service started.${NC}"
echo -e "${GREEN}[INFO] Configuration is in: ${CONFIG_DIR}${NC}"
echo -e "${GREEN}[INFO] Binary is in: ${INSTALL_DIR}${NC}"
echo "" # Keep as is (formatting)
# Final notes remain default color
echo "IMPORTANT NOTES:"
echo "*   Firewall: You may need to open UDP port 53, TCP port 80, and TCP port 443 in your firewall (e.g., sudo ufw allow 53/udp; sudo ufw allow 80/tcp; sudo ufw allow 443/tcp)."
echo "*   systemd-resolved: If you intend to bind sniproxy to 127.0.0.1:53 or 0.0.0.0:53 and systemd-resolved is using it, you must disable the systemd-resolved stub listener first (see README)."
echo "*   Logs: Check service logs using 'sudo journalctl -u ${SERVICE_NAME} -f'."
echo "*   Manage Service: Use 'sudo systemctl stop|start|restart|status ${SERVICE_NAME}'."

exit 0