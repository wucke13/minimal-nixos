# SPDX-FileCopyrightText: 2025-2026 wucke13
#
# SPDX-License-Identifier: Apache-2.0

{
  writeShellApplication,
  dnsmasq,
  iproute2,
  jq,
}:

writeShellApplication {
  name = "ad-hoc-dhcp-server";
  runtimeInputs = [
    dnsmasq
    iproute2
    jq
  ];

  text = ''
    mapfile -t NETWORK_INTERFACES < <(ip --json link show | jq --raw-output '.[].ifname')

    # help text
    if [ -z "''${1:-}" ]
    then
      echo "usage: $0 <INTERFACE> [TFTP_ROOT]"
      echo
      echo "available interfaces: ''${NETWORK_INTERFACES[*]}"
      exit 1
    fi


    IP_OUR_HOST=172.31.13.1/24
    IP_LEASE_RANGE=172.31.13.100,172.31.13.20;

    # arguments
    INTERFACE="$1"

    TFTP_ROOT=$(readlink --canonicalize -- "''${2:-tftp-root}")

    # Needed caps:
    # CAP_NET_ADMIN        - to configure ip addresses
    # CAP_NET_BIND_SERVICE - to listen on privileged ports
    CAP_EFFECTIVE=$(capsh --decode="$(grep CapEff /proc/self/status | cut -f2)")


    # check CAPs
    PRIVILEGE_ESCALATOR_NEEDED=0
    for NEEDED_CAP in cap_net_admin cap_net_bind_service
    do
      if [[ "$CAP_EFFECTIVE" != *"$NEEDED_CAP"* ]]
      then
        PRIVILEGE_ESCALATOR_NEEDED=1
        echo "missing $NEEDED_CAP"
      fi
    done


    # escalate if necessary to get CAPs
    if [ $PRIVILEGE_ESCALATOR_NEEDED != 0 ]
    then
      exec pkexec --keep-cwd "$0" "$@"
    fi

    # start collecting arguments for dnsmasq
    DNSMASQ_ARGS=(
      '--no-daemon'
      '--port=0'
      "--interface=$INTERFACE"
    )

    # check if the interface has a dynamic address
    if [ -z "$(ip address show dynamic dev "$INTERFACE")" ]
    then
      DNSMASQ_ARGS+=('--dhcp-authoritative')
    fi

    DNSMASQ_ARGS+=(
      "--dhcp-range=$IP_LEASE_RANGE"
      '--dhcp-leasefile=leases.txt'
      '--bind-dynamic'
      '--enable-tftp'
      "--tftp-root=$TFTP_ROOT"
      '--tftp-unique-root'
    )

    # run this on shutdown to clean up state modified by this tool
    cleanup(){
      # remove ip address from interface, ignore errors
      ip addr del dev "$INTERFACE" "$IP_OUR_HOST" || true

      # close firewall ports, ignore errors
      nixos-firewall-tool reset || true
    }
    trap cleanup EXIT

    # set up the interface if possible
    ip link set dev "$INTERFACE" up

    # set our ip, ignore the "Address already assigned" error, remove it afterwards
    ip addr add dev "$INTERFACE" "$IP_OUR_HOST" || true

    # open ports, ignore errors
    nixos-firewall-tool open udp bootps || true
    nixos-firewall-tool open udp tftp || true

    # actually call dnsmasq
    set -x
    dnsmasq "''${DNSMASQ_ARGS[@]}"
    { set +x; } 2>/dev/null
  '';
}
