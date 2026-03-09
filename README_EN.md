# UM Sesame

![Uptime](https://img.shields.io/endpoint?url=https%3A%2F%2Fhealthchecks.io%2Fb%2F2%2F5dc8204f-c053-4711-a9b4-c912ac52476c.shields)

> The badge above shows the live connectivity status of the author's router, monitored by [Healthchecks.io](https://healthchecks.io) — green means the network is up (script working normally), red means offline or authentication failure.

Automated captive portal login script for campus networks. Detects whether the network is behind a captive portal, submits credentials automatically, and supports unattended reconnection via cron.

> [繁體中文版](README.md) | [简体中文版](README_CN.md)

## Why?

Some IoT devices (smart appliances, printers, etc.) don't support WPA2-Enterprise with MSCHAPv2/PEAP authentication, making it impossible to connect to enterprise-encrypted campus Wi-Fi networks like `UM_SECURED_WLAN`. The fallback is to use portal-authenticated open networks (e.g. `UM_WLAN_PORTAL`), but that requires manual browser login after every disconnection.

This script solves that problem — deploy it on a router, let the router handle portal authentication automatically, and all downstream devices get internet access.

## How It Works

1. Visits public connectivity check URLs (Firefox / Microsoft) to detect portal redirection
2. Follows the redirect chain to reach the final authentication page
3. Parses dynamic parameters (`pushPageId`, `ssid`, `uaddress`, etc.) from the URL
4. Sends a POST request with login credentials to the portal server
5. Verifies the response for `"success":true`

## Requirements

- POSIX-compatible shell (`sh`, `bash`, `ash`, etc.)
- `curl`
- `logger` (for syslog output, built into most Linux distributions)

## Installation

Designed to run on routers (OpenWrt, etc.) or any Linux device. Routers typically don't have `git`, so just download directly:

```sh
# Option 1: Direct download
wget https://github.com/Victor-Quqi/um-sesame/archive/refs/heads/main.tar.gz
tar xzf main.tar.gz
mv um-sesame-main um-sesame
cd um-sesame

# Option 2: If git is available
git clone https://github.com/Victor-Quqi/um-sesame.git
cd um-sesame
```

```sh
# Create your config file
cp .env.example .env

# Fill in your credentials and login URL
vi .env

# Make scripts executable
chmod +x portal_login.sh check_connection.sh
```

`.env` example:

```
USERNAME=your_username
PASSWORD=your_password
LOGIN_URL=https://your.portal.server/portalauth/login
```

## Usage

### Auto-Reconnect (cron)

`check_connection.sh` checks connectivity and triggers the login script when the network is down. Set up a cron job for automatic reconnection:

```sh
crontab -e
```

Add the following line (checks every 5 minutes):

```
*/5 * * * * /path/to/um-sesame/check_connection.sh
```

Changes take effect immediately after saving.

Alternatively, you can edit the crontab file directly. It is usually located at `/var/spool/cron/crontabs/<username>` (Debian/Ubuntu) or `/var/spool/cron/<username>` (RHEL/CentOS/OpenWrt). After editing, run `service cron reload` or `systemctl reload cron` to apply changes.

### Manual Login

```sh
./portal_login.sh
```

### Viewing Logs

```sh
# Login records (OpenWrt)
logread | grep "PortalLogin"

# Login records (Debian/Ubuntu and similar)
grep "PortalLogin" /var/log/syslog

# Detailed debug log
cat /tmp/portal_debug.log
```

## Adapting for Other Schools

This script was originally developed for Huawei captive portal authentication systems. If your school uses a different portal, you may need to modify the POST request parameters in `portal_login.sh` to match your portal's form fields.

## Security Notes

- **TLS verification**: The script relies on curl's standard certificate and hostname verification. If the system does not trust your portal certificate, authentication may fail; bypassing verification with insecure mode would reintroduce man-in-the-middle risk.
- **Password storage**: Credentials are stored in plaintext in `.env`. Make sure to set file permissions to `600` (`chmod 600 .env`).
- **Debug logs**: The log file `/tmp/portal_debug.log` is automatically set to `600` permissions (owner-only). Passwords are masked with `***` in the logs.
- **Router environment**: Routers are typically single-user (root) environments, so the file permission risks are low. However, if other users have SSH access to the router, take care accordingly.

## License

[MIT License](LICENSE)
