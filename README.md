# Shecanak

**build your personal [shecan](https://shecan.ir)**

You can use this project to set up your own personal DNS with anti-censorship capabilities by proxying specific domains.

## Setup

Choose one of the following methods to set up Shecanak:

### Method 1: Using Docker (Recommended)

This is the recommended method as it bundles all dependencies.

1.  Ensure you have Docker and Docker Compose installed.
2.  Clone this repository:
    ```bash
    git clone <repository-url>
    cd shecanak
    ```
3.  Add the domains you would like to proxy to the `domains.csv` file, one domain per line.
4.  Build and run the containers in detached mode:
    ```bash
    docker compose up -d --build
    ```
    Your DNS server will be running on port 53.

### Method 2: Using Installation Script (Debian-based)

This method uses a script to install `sniproxy`.

**Note:** This script is primarily designed for Debian-based Linux distributions (like Ubuntu, Debian). It may require modifications for other systems.

1.  Clone this repository:
    ```bash
    git clone <repository-url>
    cd shecanak
    ```
2.  Add the domains you would like to proxy to the `domains.csv` file, one domain per line.
3.  Make the installation script executable:
    ```bash
    chmod +x install_sniproxy.sh
    ```
4.  Run the installation script with root privileges:
    ```bash
    sudo ./install_sniproxy.sh
    ```
    Your DNS server will be running on port 53.

## Troubleshooting: Port 53 Conflict with systemd-resolved

On some Linux distributions (like Ubuntu 18.04 and later), the `systemd-resolved` service runs a local DNS stub listener on `127.0.0.53:53`. This can conflict with Shecanak if it tries to bind to port 53 (either directly via the script method or through Docker).

If you encounter errors like "port already in use" or "address already in use" for port 53 when starting the service or the Docker container, follow these steps to disable the `systemd-resolved` stub listener:

1.  **Check if systemd-resolved is using port 53:**

    ```bash
    sudo ss -lp 'sport = :53'
    # Or using lsof
    # sudo lsof -i :53
    ```

    If you see `systemd-resolve` listed, it's occupying the port.

2.  **Edit the resolved configuration file:**
    Open the configuration file using a text editor with root privileges:

    ```bash
    sudo nano /etc/systemd/resolved.conf
    ```

3.  **Disable the stub listener:**
    Find the line `#DNSStubListener=yes` (it might be commented out). Uncomment it (remove the `#`) and change `yes` to `no`:

    ```
    [Resolve]
    #DNS=
    #FallbackDNS=
    #Domains=
    #LLMNR=no
    #MulticastDNS=no
    #DNSSEC=no
    #DNSOverTLS=no
    #Cache=no-negative
    DNSStubListener=no # <-- Change this line
    #ReadEtcHosts=yes
    ```

    Save the file and exit the editor (Ctrl+X, then Y, then Enter in `nano`).

4.  **Restart systemd-resolved:**
    Apply the changes by restarting the service:

    ```bash
    sudo systemctl restart systemd-resolved
    ```

5.  **Verify port 53 is free:**
    Run the check command again:

    ```bash
    sudo ss -lp 'sport = :53'
    # Or
    # sudo lsof -i :53
    ```

    You should no longer see `systemd-resolve` listening on port 53.

6.  **Update `/etc/resolv.conf` (Important):**
    Disabling the stub listener means your system might lose its DNS configuration, as `/etc/resolv.conf` often points to the stub listener (`127.0.0.53`). You need to configure your system's DNS manually or ensure your network manager (like NetworkManager or systemd-networkd) correctly updates `/etc/resolv.conf`.

    - **Option A (Recommended if using NetworkManager):** Ensure NetworkManager is configured to manage `/etc/resolv.conf`. Often, restarting NetworkManager helps: `sudo systemctl restart NetworkManager`. Check `/etc/resolv.conf` afterwards. It should now point to your actual upstream DNS servers (e.g., your router or public DNS like 1.1.1.1).
    - **Option B (Manual):** You might need to manually edit `/etc/resolv.conf` or configure your network interface settings to use specific DNS servers. _Be cautious with this, as incorrect settings can break DNS resolution._ A common temporary fix is:
      ```bash
      # Example: Using Cloudflare DNS
      echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
      echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf
      ```
      Note that this file might be overwritten by network management tools.

After completing these steps, port 53 should be available for Shecanak. You can now try starting the service or running `docker compose up -d` again.
