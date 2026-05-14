# RouterOS example for PES6 public server.
# Replace all variables before applying.

:global PublicIP "<PUBLIC_IP>"
:global ServerLanIP "<SERVER_LAN_IP>"
:global GamePcLanIP "<GAME_PC_LAN_IP>"
:global LanSubnet "<LAN_SUBNET_CIDR>"

/ip firewall nat

# Sixserver TCP services.
add chain=dstnat action=dst-nat dst-address=$PublicIP dst-port=8190,8191,10881,20200-20203 protocol=tcp to-addresses=$ServerLanIP comment="PES6 public TCP to Sixserver"

# STUN primary and alternate UDP.
add chain=dstnat action=dst-nat dst-address=$PublicIP dst-port=3478,3479 protocol=udp to-addresses=$ServerLanIP comment="PES6 public STUN UDP"

# Optional: forward the game UDP port to the LAN PC that is playing.
# Keep src-address=!$ServerLanIP so STUN replies from the local server are not captured by this dst-nat rule.
add chain=dstnat action=dst-nat dst-address=$PublicIP dst-port=5739 protocol=udp to-addresses=$GamePcLanIP to-ports=5739 src-address="!$ServerLanIP" comment="PES6 game UDP 5739 to LAN game PC"

# Generic hairpin so LAN clients can use the public IP.
add chain=srcnat action=masquerade dst-address=$ServerLanIP src-address=$LanSubnet out-interface-list=LAN comment="PES6 hairpin NAT to server"

# Preserve source UDP port 5739 for the LAN game PC when it reaches local STUN through the public IP.
# Put this before generic masquerade rules.
add chain=srcnat action=src-nat to-addresses=$PublicIP to-ports=5739 protocol=udp src-address=$GamePcLanIP dst-address=$ServerLanIP dst-port=3478,3479 comment="PES6 STUN hairpin preserve UDP 5739" place-before=0

