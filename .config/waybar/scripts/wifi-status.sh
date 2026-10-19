#!/usr/bin/env bash

# This script gathers detailed Wi-Fi connection information.
# It collects the following fields:
#
# - SSID (Service Set Identifier): The name of the Wi-Fi network you
#   are currently connected to.  Example: "My_Network"
#
# - IP Address: The IP address assigned to the device by the router.
#   This is typically a private IP within the local network.  Example:
#   "192.168.1.29/24" (with subnet mask)
#
# - Router (Gateway): The IP address of the router (default gateway)
#   that your device uses to communicate outside the local network.
#   Example: "192.168.1.1"
#
# - MAC Address: The unique Media Access Control address of the local
#   device's Wi-Fi adapter.  Example: "F8:34:41:07:1B:65"
#
# - Security: The encryption protocol being used to secure your Wi-Fi
#   connection. Common security protocols include:
#   - WPA2 (Wi-Fi Protected Access 2): The most commonly used security
#     standard, offering strong encryption (AES).
#   - WPA3: The latest version, providing even stronger security,
#     especially in public or open networks.
#   - WEP (Wired Equivalent Privacy): An outdated and insecure protocol
#     that should not be used.
#   Example: "WPA2" indicates that the connection is secured using WPA2
#   with AES encryption.
#
# - BSSID (Basic Service Set Identifier): The MAC address of the Wi-Fi
#   access point you are connected to.  Example: "A4:22:49:DA:91:A0"
#
# - Channel: The wireless channel your Wi-Fi network is using. This is
#   associated with the frequency band.  Example: "100 (5500 MHz)"
#   indicates the channel number (100) and the frequency (5500 MHz),
#   which is within the 5 GHz band.
#
# - RSSI (Received Signal Strength Indicator): The strength of the
#   Wi-Fi signal, typically in dBm (decibels relative to 1 milliwatt).
#   Closer to 0 means stronger signal, with values like -40 dBm being
#   very good.  Example: "-40 dBm"
#
# - Signal: The signal quality, which is represented as a percentage,
#   where higher numbers mean better signal.  Example: "100"
#   indicates perfect signal strength.
#
# - Rx Rate (Receive Rate): The maximum data rate (in Mbit/s) at which
#   the device can receive data from the Wi-Fi access point.  Example:
#   "866.7 MBit/s" indicates a high-speed connection on a modern
#   standard.
#
# - Tx Rate (Transmit Rate): The maximum data rate (in Mbit/s) at
#   which the device can send data to the Wi-Fi access point.  Example:
#   "866.7 MBit/s"
#
# - PHY Mode (Physical Layer Mode): The Wi-Fi protocol or standard in
#   use.  Common modes include 802.11n, 802.11ac, and 802.11ax (Wi-Fi
#   6).  Example: "802.11ac" indicates you're using the 5 GHz band with
#   a modern high-speed standard.

# --- Cost note -------------------------------------------------------------
# This used to make 5 nmcli calls per tick (two of them full AP-list dumps),
# at "interval": 1. That is ~600k D-Bus round-trips to NetworkManager per day
# and was the top context-switch source on the system.
# Now: 1 nmcli call, plus sysfs/ip for the interface and address.
# ---------------------------------------------------------------------------

if ! command -v nmcli &>/dev/null; then
  echo "{\"text\": \"󰴫\", \"tooltip\": \"nmcli utility is missing\"}"
  exit 1
fi

# Wireless interface name straight from sysfs - no subprocess.
wdev=""
for d in /sys/class/net/*/wireless; do
  [ -e "$d" ] || continue
  wdev=${d%/wireless}
  wdev=${wdev##*/}
  break
done

# Single nmcli call. SSID is requested last so that a colon inside an SSID
# cannot shift the numeric fields ahead of it.
wifi_info=$(nmcli -t -f active,signal,security,chan,freq,ssid dev wifi 2>/dev/null | grep "^yes:")

if [ -z "$wifi_info" ]; then
  # Only pay for the radio check when there is nothing connected.
  if [ "$(nmcli radio wifi 2>/dev/null)" = "disabled" ]; then
    echo "{\"text\": \"󰴮\", \"tooltip\": \"Wi-Fi Disabled\"}"
    exit 0
  fi
  essid="No Connection"
  signal=0
  tooltip="No Connection"
else
  signal=$(awk -F: '{print $2}' <<<"$wifi_info")
  security=$(awk -F: '{print $3}' <<<"$wifi_info")
  chan=$(awk -F: '{print $4}' <<<"$wifi_info")
  freq=$(awk -F: '{print $5}' <<<"$wifi_info")
  # Everything from field 6 on is the SSID; unescape nmcli's "\:".
  essid=$(awk -F: '{out=$6; for(i=7;i<=NF;i++) out=out":"$i; print out}' <<<"$wifi_info" | sed 's/\\:/:/g')

  chan="$chan ($freq)"

  ip_address="127.0.0.1"
  if [ -n "$wdev" ]; then
    # `ip` is a netlink call - no D-Bus round-trip to NetworkManager.
    addr=$(ip -4 -o addr show dev "$wdev" scope global 2>/dev/null | awk '{print $4; exit}')
    [ -n "$addr" ] && ip_address="$addr"
  fi

  tooltip=":: ${essid}"
  tooltip+="\nIP Address: ${ip_address}"
  tooltip+="\nSecurity:   ${security}"
  tooltip+="\nChannel:    ${chan}"
  tooltip+="\nStrength:   ${signal} / 100"
fi

# Determine Wi-Fi icon based on signal strength
if [ "$signal" -ge 80 ]; then
  icon="󰤨" # Strong signal
elif [ "$signal" -ge 60 ]; then
  icon="󰤥" # Good signal
elif [ "$signal" -ge 40 ]; then
  icon="󰤢" # Weak signal
elif [ "$signal" -ge 20 ]; then
  icon="󰤟" # Very weak signal
else
  icon="󰤯" # No signal
fi

# Module and tooltip
echo "{\"text\": \"${icon}\", \"tooltip\": \"${tooltip}\"}"
