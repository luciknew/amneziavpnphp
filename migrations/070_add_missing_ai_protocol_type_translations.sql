-- Add ai.protocol_type translations for non-ru locales
-- (originally added only for ru in migration 033; the key is also reused as a
-- generic "Protocol type" label on the server view page, so it must exist everywhere)
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'ai', 'protocol_type', 'Protocol type'),
('es', 'ai', 'protocol_type', 'Tipo de protocolo'),
('de', 'ai', 'protocol_type', 'Protokolltyp'),
('fr', 'ai', 'protocol_type', 'Type de protocole'),
('zh', 'ai', 'protocol_type', '协议类型')
ON DUPLICATE KEY UPDATE translation = VALUES(translation);
