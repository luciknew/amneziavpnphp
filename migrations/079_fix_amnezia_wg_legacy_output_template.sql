-- Migration 079: Fix client output_template for amnezia-wg-legacy.
-- Earlier (078) we copied the template from amnezia-wg-advanced which targets
-- AmneziaVPN (awg2-style: /32, two DNS, MTU, ::/0, keepalive=25). The standalone
-- AmneziaWG app needs the trimmer legacy format from w0rng/amnezia-wg-easy.
UPDATE protocols
SET output_template = '[Interface]
PrivateKey = {{private_key}}
Address = {{client_ip}}/24
DNS = 1.1.1.1
Jc = {{Jc}}
Jmin = {{Jmin}}
Jmax = {{Jmax}}
S1 = {{S1}}
S2 = {{S2}}
H1 = {{H1}}
H2 = {{H2}}
H3 = {{H3}}
H4 = {{H4}}

[Peer]
PublicKey = {{server_public_key}}
PresharedKey = {{preshared_key}}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 0
Endpoint = {{server_host}}:{{server_port}}'
WHERE slug = 'amnezia-wg-legacy';
