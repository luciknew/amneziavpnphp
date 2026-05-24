-- Add separate client-facing host (for NAT scenarios).
-- SSH/panel-to-server uses vpn_servers.host as before.
-- Client configs Endpoint use COALESCE(client_host, host).

SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'vpn_servers'
    AND COLUMN_NAME = 'client_host'
);

SET @sql := IF(@col_exists = 0,
  'ALTER TABLE vpn_servers ADD COLUMN client_host VARCHAR(255) NULL DEFAULT NULL AFTER host',
  'SELECT 1');

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
