-- Hide AIVPN (custom protocol from infosave2007/aivpn) from the install dropdown.
-- Closed ecosystem, requires custom client. Keep AmneziaWG 2.0 + XRay VLESS as
-- the primary, well-supported options.
-- To re-enable: UPDATE protocols SET is_active = 1 WHERE slug = 'aivpn';
UPDATE protocols SET is_active = 0 WHERE slug = 'aivpn';
