# Get-Inventory.ps1

Сбор инвентаризации Windows-станций в CSV: имя, ОС, домен, процессор,
память, диск C:, IP и MAC, дата установки, время работы.

## Запуск

```powershell
.\Get-Inventory.ps1
.\Get-Inventory.ps1 -ComputerName PC-01,PC-02 -OutputPath .\inventory.csv
Get-Content .\hosts.txt | .\Get-Inventory.ps1 -OutputPath .\inventory.csv
```

Если сценарии запрещены политикой:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Get-Inventory.ps1 -OutputPath .\inventory.csv
```

## Параметры

| Параметр | По умолчанию | Назначение |
|---|---|---|
| `-ComputerName` | текущая машина | список хостов, принимает конвейер |
| `-OutputPath` | `inventory.csv` | путь к CSV, разделитель `;`, UTF-8 |
| `-Credential` | текущий контекст | учётные данные для удалённого опроса |
| `-TimeoutSec` | 10 | таймаут подключения к одному хосту |

## Что важно в реализации

- Локальная машина опрашивается без CimSession: DCOM к самому себе падает
  с ошибкой `A specified logon session does not exist`.
- Ошибка по хосту не прерывает сбор: `status = error`, текст в колонке `error`.
- При запуске через `-File` без конвейера блок `process` не вызывается,
  поэтому список хостов из параметра добирается в блоке `end`.
