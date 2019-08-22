#!/bin/bash

((UID == 0 || EUID == 0)) || { echo "Script needs root permissions to install packages and write config files" >&2; exit 1; }

apt install udhcpd hping3 ncat iptables usb-modeswitch

source config.sh

[[ -d "$UDHCPD_DIR" ]] || mkdir -pm 755 "$UDHCPD_DIR"

if [[ -f "$UDHCPD_DIR/$UDHCPD_FILE" ]]
then
    echo "$UDHCPD_DIR/$UDHCPD_FILE exists; will not overwrite"
else
    printf "%s" "$UDHCPD_CONF" >"$UDHCPD_DIR/$UDHCPD_FILE"
fi

[[ -d "$HOSTAPD_DIR" ]] || mkdir -pm 755 "$HOSTAPD_DIR"

if [[ -f "$HOSTAPD_DIR/$HOSTAPD_FILE" ]]
then
    echo "$HOSTAPD_DIR/$HOSTAPD_FILE exists, will not overwrite"
else
    printf "%s" "$HOSTAPD_CONF" >"$HOSTAPD_DIR/$HOSTAPD_FILE"
fi

[[ -d "$UNIT_FILE_DIR" ]] || { echo "Systemd directory not found: $UNIT_FILE_DIR" >&2; exit 1; }

if [[ -f "$UNIT_FILE_DIR/$UNIT_FILE_NAME" ]]
then
    echo "$UNIT_FILE_DIR/$UNIT_FILE_NAME exists, will not overwrite"
    echo "Make sure the path to the phone_home script in the unit file is correct"
else
    printf "%s" "$UNIT_FILE_CONF" >"$UNIT_FILE_DIR/$UNIT_FILE_NAME"
fi
