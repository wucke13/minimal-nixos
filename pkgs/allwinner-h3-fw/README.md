# Quick Bootstrapping Notes

- Connect the device via Ethernet to your development host, preferably via a dedicated interface.
- Power-on the device via USB connected to your development host.

```bash
# load uboot only via USB/fel
nix run .\#allwinner-h3-fw.passthru.uboot.passthru.felBoot

# get a console on device
# Might require changing the device, look in /dev/serial/by-id for available serial devices.
picocom -b 115200 /dev/ttyUSB0
# open an additional terminal

# build the needed files for tftp boot
nix build --out-link result-tftp-root .\#allwinner-h3-fw.passthru.tftp-root

# spawn a dhcp + tftp server
# Might require changing the interface. Run without interface to get a list of available ones.
TFTP_ROOT=result-tftp-root nix run .\#ad-hoc-dhcp-server eth0 result-tftp-root
```

```uboot
# to start the loading via TFTP
if dhcp ${scriptaddr} ${boot_script_dhcp}; then source ${scriptaddr}; fi
```
