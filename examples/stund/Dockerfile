FROM ubuntu:20.04

ARG STUND_URL="https://downloads.sourceforge.net/project/stun/stun/0.96/stund_0.96_Aug13.tgz"
ARG STUN_PUBLIC_IP=""
ARG STUN_PRIMARY_IP=""
ARG STUN_ALT_IP=""

ENV DEBIAN_FRONTEND=noninteractive
ENV STUN_PUBLIC_IP="${STUN_PUBLIC_IP}"
ENV STUN_PRIMARY_IP="${STUN_PRIMARY_IP}"
ENV STUN_ALT_IP="${STUN_ALT_IP}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    build-essential \
    patch \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Source: Vovida STUN 0.96, mirrored by SourceForge as stund_0.96_Aug13.tgz.
# FreeBSD's net/stund port also points to this distfile.
RUN wget -O /tmp/stund.tgz "${STUND_URL}" \
  && mkdir -p /opt/stund-src \
  && tar -xzf /tmp/stund.tgz -C /opt/stund-src --strip-components=1

WORKDIR /opt/stund-src

COPY stun-public-ip.patch /tmp/stun-public-ip.patch

# Old Vovida code needs a small compile fix on modern Linux.
# The patch adds STUN_PUBLIC_IP support so PES6 sees the public IP in SourceAddress/ChangedAddress.
RUN sed -i 's/#     error Need some way to seed the random number generator/srandom(time(NULL));/g' stun.cxx \
  && patch -p0 < /tmp/stun-public-ip.patch \
  && (make clean || true) \
  && make

EXPOSE 3478/udp
EXPOSE 3479/udp

CMD ["sh", "-c", "test -n \"$STUN_PRIMARY_IP\" && test -n \"$STUN_ALT_IP\" && exec ./server -v -h \"$STUN_PRIMARY_IP\" -a \"$STUN_ALT_IP\""]
