# Shecanak

**build your personal [shecan](https://shecan.ir)**

you can use this project to setup your own personal DNS with anti-censorship capabilities.
simply add domains you would like to proxy in `domains.csv` and then run `docker compose up -d --build`.

## Troubleshooting: Port 53 Conflict with systemd-resolved

On some Linux distributions (like Ubuntu 18.04 and later), the `systemd-resolved` service runs a local DNS stub listener on `127.0.0.53:53`. This can conflict with `sniproxy` if you intend to bind it to port 53 on all interfaces (`0.0.0.0:53`) or the loopback interface (`127.0.0.1:53`).

If you encounter errors like "port already in use" or "address already in use" for port 53 when starting the Docker container, follow these steps to disable the `systemd-resolved` stub listener:

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

After completing these steps, port 53 should be available for the `sniproxy` Docker container. You can now try running `docker compose up -d` again.
