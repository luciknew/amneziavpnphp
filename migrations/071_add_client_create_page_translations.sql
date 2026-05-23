-- Translations for the new "Add Client" dashboard button and standalone page
INSERT INTO translations (locale, category, key_name, translation) VALUES
('en', 'clients', 'add', 'Add Client'),
('ru', 'clients', 'add', 'Добавить клиента'),
('es', 'clients', 'add', 'Añadir cliente'),
('de', 'clients', 'add', 'Client hinzufügen'),
('fr', 'clients', 'add', 'Ajouter un client'),
('zh', 'clients', 'add', '添加客户端'),

('en', 'clients', 'no_active_servers', 'No active servers. Add and deploy a server first.'),
('ru', 'clients', 'no_active_servers', 'Нет активных серверов. Сначала добавьте и разверните сервер.'),
('es', 'clients', 'no_active_servers', 'No hay servidores activos. Primero añade y despliega un servidor.'),
('de', 'clients', 'no_active_servers', 'Keine aktiven Server. Bitte zuerst einen Server hinzufügen und bereitstellen.'),
('fr', 'clients', 'no_active_servers', 'Aucun serveur actif. Ajoutez et déployez d''abord un serveur.'),
('zh', 'clients', 'no_active_servers', '没有活动的服务器。请先添加并部署服务器。'),

('en', 'common', 'select', 'Select'),
('ru', 'common', 'select', 'Выбрать'),
('es', 'common', 'select', 'Seleccionar'),
('de', 'common', 'select', 'Auswählen'),
('fr', 'common', 'select', 'Sélectionner'),
('zh', 'common', 'select', '选择'),

('en', 'common', 'back', 'Back'),
('ru', 'common', 'back', 'Назад'),
('es', 'common', 'back', 'Atrás'),
('de', 'common', 'back', 'Zurück'),
('fr', 'common', 'back', 'Retour'),
('zh', 'common', 'back', '返回')
ON DUPLICATE KEY UPDATE translation = VALUES(translation);
