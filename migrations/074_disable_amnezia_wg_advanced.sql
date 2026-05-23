-- Temporarily hide AmneziaWG Advanced (kernel-module variant) from the install dropdown.
-- AmneziaWG 2.0 (userspace amneziawg-go) covers the same use case with fewer host
-- prerequisites. To re-enable: UPDATE protocols SET is_active = 1 WHERE slug = 'amnezia-wg-advanced';
UPDATE protocols SET is_active = 0 WHERE slug = 'amnezia-wg-advanced';
