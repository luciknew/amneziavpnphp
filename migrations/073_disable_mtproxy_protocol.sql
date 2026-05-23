-- Temporarily disable MTProxy (Telegram) protocol in the installation dropdown.
-- We'll re-enable it later (likely with SNI-routing fronting + port consolidation).
-- To re-enable manually: UPDATE protocols SET is_active = 1 WHERE slug = 'mtproxy';
UPDATE protocols SET is_active = 0 WHERE slug = 'mtproxy';
