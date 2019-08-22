# Array of MACs of all interfaces that may be used to phone home. Currently only
# contains MAC address of our Huawei e3372 umts stick.
MACS=()

# List of ip:port combinations to try to ssh into. Values here just for
# reference.
HOMES=()

# Port on which the local ssh server listens
SSHD_PORT=22

# SSHD binary to use on the rbpi. If empty or unset, systemctl is used to just
# start whichever binary is configured in the ssh unit file.
SSHD_BIN=""

# If set to 1, the script will never start a wireless hotspot.
#
# If set to 0, the script will start a wireless hotspot inconspicuously named
# "John's Iphone" which can be used as a fallback in case broadband internet
# as primary communication method becomes unavailable.
DISABLE_HOTSPOT=0

# Access point name
AP_ESSID="John's Iphone"

# Access point password
AP_PASS="changeme123"

# IP address of access point. If the CIDR is changed, the udhcpd config below
# may also have to be adjusted (assuming you care about the convenience of dhcp)
AP_IP="192.168.1.1/27"

# Wireless interface for hotspot.
WIRELESS_IFACE='wlan0'

# config file locations for setting up udhcpd and hostapd
UDHCPD_DIR='/etc/udhcpd'
UDHCPD_FILE='udhcpd.conf'
HOSTAPD_DIR='/etc/hostapd'
HOSTAPD_FILE='hostapd.conf'

# If set to 1, the rbpi will reboot after approximately 4 minutes of trying to
# connect to the internet.
FAILURE_REBOOT=1

# Set to 1 to report check failures to /tmp/usb_chk_log without taking further
# action
USB_DEBUG=0

# A known good output of lsusb goes here. What is bad lsusb output? Any output
# containing devices that are not expected. If unexpected devices show up, the
# rbpi will shut down.
# To reduce the chances of soft bricking your device through misconfiguration, 
# the # USB_DEBUG flag can be used. If the device gets bricked, just mount the
# sdcard somewhere else and remove the appropriate service symlink from the
# appropriate directory which is probably
# /etc/systemd/system/multi-user.target.wants/. Leave this parameter empty to
# disable the feature, but anyone will be able to easily poke around unencrypted
# storage space. Note that the checks performed are very rudimentary and will
# only be a minor annoyance for a determined attacker when probing your device.
# Always store project files in an encrypted volume (at minimum).
GOOD_USB=""

# Systemd unit dir and unit file
UNIT_FILE_DIR="/lib/systemd/system"
UNIT_FILE_NAME="phone_home.service"

# determine location of calling script
SCRIPTDIR="$(dirname "$(readlink -f "$0")")"

# Systemd unit file config to run during startup
UNIT_FILE_CONF="[Unit]
Description=start phone home script
After=network.target auditd.service

[Service]
ExecStart=${SCRIPTDIR}/phone_home.sh

[Install]
WantedBy=multi-user.target"

# udhcpd config to be written to its config file
UDHCPD_CONF="#start and end of lease block
start       192.168.1.10
end         192.168.1.30
max_leases  21

#interface that udhcpd shall use
interface   $WIRELESS_IFACE

#other dhcp options
opt subnet 255.255.255.224
opt router 192.168.1.1
opt dns 8.8.8.8
opt lease 864000    #10 day lease time"

# hostapd config to be written to its config file
HOSTAPD_CONF="interface=$WIRELESS_IFACE
logger_syslog=-1
logger_syslog_level=1
logger_stdout=-1
logger_stdout_level=2
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
ssid=$AP_ESSID
country_code=CH
hw_mode=g
channel=2
beacon_int=100
dtim_period=2
max_num_sta=255
rts_threshold=-1
fragm_threshold=-1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wmm_enabled=1
wmm_ac_bk_cwmin=4
wmm_ac_bk_cwmax=10
wmm_ac_bk_aifs=7
wmm_ac_bk_txop_limit=0
wmm_ac_bk_acm=0
wmm_ac_be_aifs=3
wmm_ac_be_cwmin=4
wmm_ac_be_cwmax=10
wmm_ac_be_txop_limit=0
wmm_ac_be_acm=0
wmm_ac_vi_aifs=2
wmm_ac_vi_cwmin=3
wmm_ac_vi_cwmax=4
wmm_ac_vi_txop_limit=94
wmm_ac_vi_acm=0
wmm_ac_vo_aifs=2
wmm_ac_vo_cwmin=2
wmm_ac_vo_cwmax=3
wmm_ac_vo_txop_limit=47
wmm_ac_vo_acm=0
eapol_key_index_workaround=0
eap_server=0
own_ip_addr=127.0.0.1
wpa=2
wpa_passphrase=$AP_PASS
wpa_key_mgmt=WPA-PSK WPA-PSK-SHA256
wpa_disable_eapol_key_retries=1"


