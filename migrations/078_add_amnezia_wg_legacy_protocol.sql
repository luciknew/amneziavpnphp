-- =====================================================================
-- Migration 078: Add legacy AmneziaWG protocol (separate from AWG 2.0)
-- For the standalone AmneziaWG mobile app (not AmneziaVPN).
-- Reference: w0rng/amnezia-wg-easy uses amneziavpn/amnezia-wg:latest image.
-- Uses kernel-module AmneziaWG installed on host via amnezia/ppa.
-- =====================================================================

INSERT INTO protocols (name, slug, description, install_script, uninstall_script, output_template, show_text_content, ubuntu_compatible, is_active, definition, created_at, updated_at)
SELECT
  'AmneziaWG',
  'amnezia-wg-legacy',
  'AmneziaWG (legacy) — kernel-module based. For the standalone AmneziaWG mobile/desktop app (separate from AmneziaWG 2.0 which targets AmneziaVPN).',
  '#!/bin/bash
set -euo pipefail

CONTAINER_NAME="${SERVER_CONTAINER:-amnezia-wg}"
PORT_RANGE_START=${PORT_RANGE_START:-30000}
PORT_RANGE_END=${PORT_RANGE_END:-65000}
VPN_PORT="${SERVER_PORT:-$((RANDOM % (PORT_RANGE_END - PORT_RANGE_START + 1) + PORT_RANGE_START))}"
SUBNET_BASE="${SUBNET_BASE:-10.9.0}"   # different from awg2 (10.8.x) so they can coexist
MTU=${MTU:-1420}
CONFIG_DIR="/opt/amnezia/wg"
IMAGE="amneziavpn/amnezia-wg:latest"

mkdir -p "$CONFIG_DIR"

# Ensure amneziawg kernel module is available on host (PPA install once)
if ! lsmod 2>/dev/null | grep -q "^amneziawg" && ! modprobe amneziawg 2>/dev/null; then
  echo "Installing amneziawg kernel module from amnezia/ppa..."
  apt-get update -qq
  apt-get install -y -qq software-properties-common >/dev/null 2>&1 || true
  add-apt-repository -y ppa:amnezia/ppa >/dev/null 2>&1 || true
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq amneziawg amneziawg-tools >/dev/null 2>&1
  modprobe amneziawg || { echo "ERROR: amneziawg kernel module load failed (kernel headers missing?)"; exit 1; }
fi

# Pull official AmneziaWG image
docker pull "$IMAGE" >/dev/null 2>&1 || true

# Idempotent run
EXISTING=$(docker ps -aq -f "name=$CONTAINER_NAME" 2>/dev/null | head -1)
if [ -z "$EXISTING" ]; then
  docker run -d --name "$CONTAINER_NAME" --restart always \
    --cap-add=NET_ADMIN --cap-add=SYS_MODULE \
    --device /dev/net/tun \
    -v /lib/modules:/lib/modules:ro \
    -p "${VPN_PORT}:${VPN_PORT}/udp" \
    -v "$CONFIG_DIR:/etc/amnezia/amneziawg" \
    "$IMAGE" \
    sh -c "while [ ! -f /etc/amnezia/amneziawg/wg0.conf ]; do sleep 1; done; awg-quick up wg0 && sleep infinity"
  sleep 2
else
  STATUS=$(docker inspect --format="{{.State.Status}}" "$CONTAINER_NAME" 2>/dev/null || echo "")
  if [ "$STATUS" != "running" ]; then
    docker start "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
fi

# Reuse existing config if present
if [ -f "$CONFIG_DIR/wg0.conf" ]; then
  PORT=$(grep -E "^ListenPort" "$CONFIG_DIR/wg0.conf" | cut -d= -f2 | tr -d "[:space:]")
  PSK=$(cat "$CONFIG_DIR/wireguard_psk.key" 2>/dev/null || true)
  PUBKEY=$(cat "$CONFIG_DIR/wireguard_server_public_key.key" 2>/dev/null || true)
  echo "Using existing AmneziaWG configuration"
  echo "Port: ${PORT:-$VPN_PORT}"
  if [ -n "${PUBKEY:-}" ]; then echo "Server Public Key: $PUBKEY"; fi
  if [ -n "${PSK:-}" ]; then echo "PresharedKey = $PSK"; fi
  EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
  echo "Server Host: $EXTERNAL_IP"
  for P in Jc Jmin Jmax S1 S2 H1 H2 H3 H4; do
    VAL=$(grep -E "^$P " "$CONFIG_DIR/wg0.conf" | cut -d= -f2 | tr -d "[:space:]")
    if [ -n "$VAL" ]; then echo "Variable: $P=$VAL"; fi
  done
  echo "Variable: dns_servers=1.1.1.1"
  exit 0
fi

# Generate keys via container
PRIVATE_KEY=$(docker exec "$CONTAINER_NAME" awg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | docker exec -i "$CONTAINER_NAME" awg pubkey)
PRESHARED_KEY=$(docker exec "$CONTAINER_NAME" awg genpsk)

# Legacy AWG obfuscation params (NO S3/S4/I1-I5 — those are AWG 2.0)
JC=$((RANDOM % 6 + 3))
JMIN=$((RANDOM % 41 + 10))
JMAX=$((JMIN + RANDOM % 951 + 50))
S1_VAL=$((RANDOM % 100 + 15))
S2_VAL=$((RANDOM % 100 + 15))
H1_VAL=$((RANDOM * RANDOM % 2000000000 + 100000))
H2_VAL=$((RANDOM * RANDOM % 2000000000 + 100000))
H3_VAL=$((RANDOM * RANDOM % 2000000000 + 100000))
H4_VAL=$((RANDOM * RANDOM % 2000000000 + 100000))

cat > "$CONFIG_DIR/wg0.conf" << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = ${SUBNET_BASE}.1/24
ListenPort = $VPN_PORT
MTU = $MTU
Jc = $JC
Jmin = $JMIN
Jmax = $JMAX
S1 = $S1_VAL
S2 = $S2_VAL
H1 = $H1_VAL
H2 = $H2_VAL
H3 = $H3_VAL
H4 = $H4_VAL
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

echo "$PRIVATE_KEY" > "$CONFIG_DIR/wireguard_server_private_key.key"
echo "$PUBLIC_KEY"  > "$CONFIG_DIR/wireguard_server_public_key.key"
echo "$PRESHARED_KEY" > "$CONFIG_DIR/wireguard_psk.key"
echo "[]" > "$CONFIG_DIR/clientsTable"
chmod 600 "$CONFIG_DIR"/*.key "$CONFIG_DIR/wg0.conf"

# (Re)start awg-quick inside container to pick up new config
docker exec "$CONTAINER_NAME" sh -c "awg-quick down wg0 2>/dev/null || true; awg-quick up wg0"

EXTERNAL_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "YOUR_SERVER_IP")
echo "AmneziaWG (legacy) installed successfully"
echo "Port: $VPN_PORT"
echo "Server Public Key: $PUBLIC_KEY"
echo "PresharedKey = $PRESHARED_KEY"
echo "Server Host: $EXTERNAL_IP"
echo "Variable: Jc=$JC"
echo "Variable: Jmin=$JMIN"
echo "Variable: Jmax=$JMAX"
echo "Variable: S1=$S1_VAL"
echo "Variable: S2=$S2_VAL"
echo "Variable: H1=$H1_VAL"
echo "Variable: H2=$H2_VAL"
echo "Variable: H3=$H3_VAL"
echo "Variable: H4=$H4_VAL"
echo "Variable: dns_servers=1.1.1.1"',
  '#!/bin/bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-amnezia-wg}"

docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm -fv "$CONTAINER_NAME" 2>/dev/null || true
rm -rf /opt/amnezia/wg 2>/dev/null || true

echo "{\"success\":true,\"message\":\"AmneziaWG (legacy) uninstalled\"}"',
  p.output_template,
  p.show_text_content,
  1,
  1,
  JSON_OBJECT(
    'engine', 'shell',
    'metadata', JSON_OBJECT(
      'container_name', 'amnezia-wg',
      'vpn_subnet', '10.9.0.0/24',
      'port_range', JSON_ARRAY(30000, 65000),
      'config_dir', '/opt/amnezia/wg'
    )
  ),
  NOW(),
  NOW()
FROM protocols p
WHERE p.slug = 'amnezia-wg-advanced'
  AND NOT EXISTS (SELECT 1 FROM protocols WHERE slug = 'amnezia-wg-legacy');

-- Copy protocol_templates (clone from advanced as starting point — we'll override below)
INSERT INTO protocol_templates (protocol_id, template_name, template_content, is_default)
SELECT
  (SELECT id FROM protocols WHERE slug = 'amnezia-wg-legacy' LIMIT 1),
  'Default AmneziaWG (legacy)',
  '[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/24
DNS = 1.1.1.1
Jc = {{jc}}
Jmin = {{jmin}}
Jmax = {{jmax}}
S1 = {{s1}}
S2 = {{s2}}
H1 = {{h1}}
H2 = {{h2}}
H3 = {{h3}}
H4 = {{h4}}

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 0
Endpoint = {{server_host}}:{{server_port}}',
  1
WHERE NOT EXISTS (
  SELECT 1 FROM protocol_templates pt
  JOIN protocols p ON p.id = pt.protocol_id
  WHERE p.slug = 'amnezia-wg-legacy'
);
