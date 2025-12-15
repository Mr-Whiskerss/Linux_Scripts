![tux_script_logo_small](https://github.com/user-attachments/assets/ff22afb6-ff0b-4d84-967f-6d16946c0549)




# Linux Scripts

A collection of Bash scripts for penetration testing and Linux system administration, built from real-world engagements and daily use.

## Scripts

| Script | Description |
|--------|-------------|
| **Network_ConfigurationV3.sh** | Configure IP address and DNS settings manually. Ideal for pentest exams or on-site engagements where DHCP isn't available or you need a specific network config. |
| **Python_configurator.sh** | Set up Python 2 and Python 3 development environments with required dependencies. |
| **build_script.sh** | Bootstrap a fresh Linux install with common pentesting tools and configurations. Personal go-to for new VM builds. |
| **update_v2.0.sh** | Quick system update script for Debian-based distributions (apt update, upgrade, autoremove). |

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Mr-Whiskerss/Linux_Scripts.git
cd Linux_Scripts

# Make scripts executable
chmod +x *.sh

# Run a script
./script_name.sh
```

## Requirements

- Linux (Debian-based for update scripts)
- Bash shell
- Sudo privileges (required for network config, package installation, and updates)

## ⚠️ Disclaimer

These scripts are provided as-is for personal use and learning. Always review scripts before running them, especially in production environments. Modify as needed for your setup.

## Contributing

Pull requests and suggestions welcome. Feel free to fork, modify, and share.

## License

Free to use and modify.
