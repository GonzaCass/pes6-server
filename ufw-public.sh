#!/usr/bin/env sh
set -eu

# Public PES6 ports.
ufw allow 10881/tcp comment "PES6 game list"
ufw allow 20200:20203/tcp comment "PES6 services"
ufw allow 8190/tcp comment "PES6 registration"
ufw allow 3478/udp comment "PES6 STUN primary"
ufw allow 3479/udp comment "PES6 STUN alternate"
ufw allow 5739/udp comment "PES6 game UDP"

# If using Traefik in Docker and exposing the stats API only through /public,
# allow 8192 only from the Docker network used by Traefik.
# Replace the subnet with your actual docker network range.
ufw allow proto tcp from <TRAEFIK_DOCKER_SUBNET> to any port 8192 comment "PES6 stats API from reverse proxy"

