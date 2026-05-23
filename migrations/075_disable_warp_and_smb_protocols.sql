-- Temporarily hide Cloudflare WARP Proxy and SMB Server from the install dropdown.
-- Focus the UI on the primary VPN protocols (AmneziaWG 2.0, XRay VLESS, AIVPN).
-- To re-enable manually:
--   UPDATE protocols SET is_active = 1 WHERE slug IN ('cf-warp', 'smb');
UPDATE protocols SET is_active = 0 WHERE slug IN ('cf-warp', 'smb');
