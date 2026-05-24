-- Add separate SSH Host column for servers behind NAT / in private networks.
-- `host` continues to be the public Endpoint that goes into client configs.
-- `ssh_host` is what the panel connects to for installation/management.
-- When NULL, code falls back to `host` (backward compatibility).
ALTER TABLE vpn_servers
  ADD COLUMN ssh_host VARCHAR(255) NULL AFTER host;
