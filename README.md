# OpenWRT-Scrypt

Скрипты для **потключения** и **включения** IPv6 на OpenWRT.

---

## Быстрый запуск

Выполните команду в терминале роутера.

Выбирите, что Вам нужно:
1) Включить IPv6
2) Выключить IPv6
0) Отмена        

```
sh <(wget -O - https://raw.githubusercontent.com/StressOzz/OpenWRT-Scrypt/main/IPv6-On-Off.sh)
```

### Отключить IPv6
```
sh <(wget -O - https://raw.githubusercontent.com/StressOzz/OpenWRT-Scrypt/main/OpenWRT-IPv6-OFF.sh)
```

### Включить IPv6
```
sh <(wget -O - https://raw.githubusercontent.com/StressOzz/OpenWRT-Scrypt/main/OpenWRT-IPv6-ON.sh)
```

### Примечание

Для надёжности рекомендуется перезагрузить роутер:
```
reboot
```
