# Next session — где остановились (forked from session ~2026-05-23)

## Что уже сделано в этой сессии

### 1. Базовая работа панели
- Поднята локально/на awg-admin (10.30.5.254), VPN-сервер frknavpn (10.30.5.253).
- Форк: `git@github.com:luciknew/amneziavpnphp.git`, ветка `me-1`.
- Auto-install Composer deps в Dockerfile (vendor volume + start.sh fallback).
- LDAP libdir архитектурно-независимый (dpkg-architecture).

### 2. Установка серверов
- VPN порт: рандомный (30000-65000) в форме, можно менять (см. `templates/servers/create.twig`).
- Apache `Timeout 900`, PHP `set_time_limit(0) + ignore_user_abort + ob_start/clean` —
  длинный deploy больше не валится с "Invalid server response".
- Фикс PHP-warning `Undefined variable $IFACE` в `VpnServer.php` (host-level NAT/forwarding).
- Динамическое определение `wg` vs `awg` бинарника в контейнере (slug-based routing ломался для awg2 → builtin AWG).

### 3. UI улучшения
- Кнопка "Add Client" на dashboard + новая страница `/clients/create` с dropdown серверов.
- Глобальная страница `/clients` со поиском и пагинацией (20/50/75/100).
- Пункт меню "Clients" в navbar.
- Поля формы клиента: имя → сервер → протокол → срок → лимит (в этом порядке).
- Confirm-modal стрейчился на весь экран — пофикшено (`items-start justify-center self-start`).

### 4. Метрики
- `bin/collect_metrics.php` живёт в logs/, разделён monitor.lock и collect.lock.
- `monitor_metrics.sh` использует `setsid` + `200>&-` чтобы child не наследовал OFD lock.
- `update.sh` показывает прогресс билда (убрал `grep -v "^#"`) + правильный PID-path.

### 5. Спрятаны лишние протоколы (миграции 073-076)
Сейчас активны только: **AmneziaWG 2.0** + **XRay VLESS**. Остальные `is_active=0`.
- 073: MTProxy
- 074: AmneziaWG Advanced
- 075: Cloudflare WARP + SMB
- 076: AIVPN

Вернуть любой: `UPDATE protocols SET is_active = 1 WHERE slug = '<slug>';`

## Открытые вопросы (НА КОГДА ВЕРНЁМСЯ)

Контекст: пользователь хочет добавить отдельные **AmneziaWG (legacy client)** и **WireGuard** протоколы рядом с AWG 2.0, чтобы:
1. QR с AWG 2.0 сейчас НЕ работает для standalone AmneziaWG-приложения (только для AmneziaVPN).
2. Standard WireGuard клиент не подключается к AmneziaWG-серверу (junk-обфускация).
3. Все протоколы должны жить в отдельных контейнерах + отдельных портах на одной VPS.

### Корни проблемы (выяснил)
1. **QR код AWG 2.0** идёт через `QrUtil::encodeOldPayloadFromConf` (Qt/QDataStream + gzcompress + base64) — Amnezia-специфичный wrap, standalone-клиент его не парсит.
2. **Шаблон conf** имеет `Jc/Jmin/...H4` после `[Peer]` блока — standalone AmneziaWG ждёт их в `[Interface]`.
3. **AWG сервер с обфускацией** не примет стандартный WG-клиент (нет junk-пакетов).

### План в двух фазах

**Фаза 1 (быстро) — фикс AWG 2.0 для standalone AmneziaWG клиента:**
- Миграция: перенести `Jc/Jmin/Jmax/S1/S2/H1..H4` в секцию `[Interface]` (templates `protocol_templates.template_content`).
- Добавить **третий QR-вариант** "plain .conf text" наряду с "Amnezia old" и "vpn://".
  - Изменения в `inc/VpnClient.php` (`generateQRCode*` методы) + `templates/clients/view.twig`.

**Фаза 2 — отдельный WireGuard протокол:**
- Новый slug `wg`, name "WireGuard".
- Новый контейнер, отдельный UDP-порт.
- Шаблон .conf без `Jc/Jmin/...`.
- Образ — на выбор:
  - `linuxserver/wireguard` — стандарт, поддерживается, требует kernel-module WG на хосте.
  - Свой alpine + `wireguard-go` (userspace) — как awg2, работает везде без kernel.

### Вопросы которые я задавал, на которые НЕ ОТВЕТИЛ пользователь:

1. **WG image:** `linuxserver/wireguard` (kernel) или свой alpine + `wireguard-go` (userspace)?
2. **Порядок:** сначала Фаза 1 (QR-фикс), потом Фаза 2 (WG)? Или сразу всё?

## Полезные команды для подхвата

```bash
# Применить все миграции что лежат, но ещё не применены:
cd ~/amneziavpnphp
for m in 071 072 073 074 075 076; do
  docker compose exec -T db mysql -uamnezia -pamnezia amnezia_panel < migrations/${m}_*.sql
done

# Проверить активные протоколы:
docker compose exec -T db mysql -uamnezia -pamnezia -h db amnezia_panel \
  -e "SELECT slug, name, is_active FROM protocols ORDER BY is_active DESC, slug"

# Проверить шаблон AWG 2.0:
docker compose exec -T db mysql -uamnezia -pamnezia -h db amnezia_panel \
  -e "SELECT template_content FROM protocol_templates WHERE protocol_id=(SELECT id FROM protocols WHERE slug='awg2') \G"

# Проверить состояние коллектора метрик:
docker compose exec -T web sh -c 'pgrep -af collect_metrics; tail -5 /var/log/metrics_collector.log'
```

## Доступы

- awg-admin (панель): `ubuntu@10.30.5.254` — ключ установлен
- frknavpn (VPN): `root@10.30.5.253` — ключ установлен
- БД пароль: `amnezia` (в .env, не `amnezia123` как я ошибочно писал ранее)
