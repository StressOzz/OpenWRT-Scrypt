# OpenWRT-Scrypt

Скрипты для **полного отключения** и **включения обратно** IPv6 на OpenWRT 24+.

- `OpenWRT-IPv6-OFF` — полностью отключает IPv6 (LAN/WAN/DHCPv6/RA/sysctl).
- `OpenWRT-IPv6-ON` — возвращает IPv6 обратно.

---

## Быстрый запуск

Просто вставь одну команду в терминале роутера:

### Отключить IPv6
```
bash <(curl -sSL https://raw.githubusercontent.com/StressOzz/OpenWRT-Scrypt/main/OpenWRT-IPv6-OFF)
```

### Включить IPv6
```
bash <(curl -sSL https://raw.githubusercontent.com/StressOzz/OpenWRT-Scrypt/main/OpenWRT-IPv6-ON)
```
