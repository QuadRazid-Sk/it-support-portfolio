#requires -Version 5.1
<#
.SYNOPSIS
    Собирает инвентаризацию рабочих станций Windows в CSV.

.DESCRIPTION
    Опрашивает локальный или удалённые компьютеры через CIM и выгружает
    имя, ОС, домен, процессор, объём памяти, диск C:, IP и MAC, дату установки
    и время работы. Недоступный хост не роняет сбор: он попадает в CSV
    со статусом error и текстом ошибки.

    Локальная машина опрашивается напрямую, удалённые — через CimSession:
    DCOM-сессия к самому себе на части конфигураций падает с ошибкой
    "A specified logon session does not exist".

.PARAMETER ComputerName
    Список машин. По умолчанию — текущая.

.PARAMETER OutputPath
    Путь к CSV. По умолчанию inventory.csv в текущей папке.

.PARAMETER Credential
    Учётные данные для удалённого опроса, если текущих прав недостаточно.

.PARAMETER TimeoutSec
    Таймаут на подключение к одной машине, сек.

.EXAMPLE
    .\Get-Inventory.ps1 -ComputerName PC-01,PC-02 -OutputPath .\inventory.csv

.EXAMPLE
    Get-Content .\hosts.txt | .\Get-Inventory.ps1 -OutputPath .\inventory.csv
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline = $true)]
    [string[]]$ComputerName = @($env:COMPUTERNAME),

    [string]$OutputPath = (Join-Path (Get-Location) "inventory.csv"),

    [System.Management.Automation.PSCredential]$Credential,

    [ValidateRange(1, 120)]
    [int]$TimeoutSec = 10
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $rows = [System.Collections.Generic.List[object]]::new()
    $localNames = @($env:COMPUTERNAME, 'localhost', '.', '127.0.0.1') | ForEach-Object { $_.ToLower() }

    function New-InventoryRow {
        param([string]$Target)

        # все поля объявлены заранее: StrictMode не даст обратиться к отсутствующему ключу
        return [pscustomobject][ordered]@{
            computer        = $Target
            status          = 'ok'
            error           = ''
            os              = ''
            domain          = ''
            user            = ''
            cpu             = ''
            cpu_logical     = 0
            ram_gb          = 0
            disk_c_free_gb  = 0
            disk_c_total_gb = 0
            disk_c_free_pct = 0
            ip              = ''
            mac             = ''
            os_installed    = ''
            last_boot       = ''
            uptime_days     = 0
        }
    }

    function Get-CimData {
        param($Session, [string]$ClassName, [string]$Filter)

        $args = @{ ClassName = $ClassName; ErrorAction = 'Stop' }
        if ($Session) { $args['CimSession'] = $Session }
        if ($Filter) { $args['Filter'] = $Filter }
        return Get-CimInstance @args
    }

    function Get-Inventory {
        param([string]$Target, $Cred)

        $row = New-InventoryRow -Target $Target
        $session = $null
        $isLocal = $localNames -contains $Target.ToLower()

        try {
            if (-not $isLocal) {
                $sessionArgs = @{
                    ComputerName        = $Target
                    OperationTimeoutSec = $TimeoutSec
                    ErrorAction         = 'Stop'
                }
                if ($Cred) { $sessionArgs['Credential'] = $Cred }
                $session = New-CimSession @sessionArgs
            }

            $os = Get-CimData -Session $session -ClassName Win32_OperatingSystem |
                Select-Object -First 1
            $cs = Get-CimData -Session $session -ClassName Win32_ComputerSystem |
                Select-Object -First 1
            $cpu = Get-CimData -Session $session -ClassName Win32_Processor |
                Select-Object -First 1
            $disk = Get-CimData -Session $session -ClassName Win32_LogicalDisk `
                -Filter "DeviceID='C:'" | Select-Object -First 1

            $nics = Get-CimData -Session $session -ClassName Win32_NetworkAdapterConfiguration `
                -Filter "IPEnabled = TRUE"
            $nic = $nics | Where-Object { $_.DefaultIPGateway } | Select-Object -First 1
            if (-not $nic) { $nic = $nics | Select-Object -First 1 }

            $row.os = ($os.Caption -replace '^Microsoft\s+', '').Trim()
            if ($os.InstallDate) {
                $row.os_installed = ([datetime]$os.InstallDate).ToString('dd.MM.yyyy')
            }
            if ($os.LastBootUpTime) {
                $boot = [datetime]$os.LastBootUpTime
                $row.last_boot = $boot.ToString('dd.MM.yyyy HH:mm')
                $row.uptime_days = [math]::Round(((Get-Date) - $boot).TotalDays, 1)
            }

            $row.cpu = $cpu.Name.Trim()
            $row.cpu_logical = [int]$cs.NumberOfLogicalProcessors
            $row.ram_gb = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)

            if ($disk -and $disk.Size -gt 0) {
                $row.disk_c_total_gb = [math]::Round($disk.Size / 1GB, 1)
                $row.disk_c_free_gb = [math]::Round($disk.FreeSpace / 1GB, 1)
                $row.disk_c_free_pct = [math]::Round(100 * $disk.FreeSpace / $disk.Size, 1)
            }

            $row.domain = if ($cs.PartOfDomain) { $cs.Domain } else { 'WORKGROUP' }
            $row.user = $cs.UserName

            if ($nic) {
                $ipv4 = $nic.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }
                $row.ip = $ipv4 -join ', '
                $row.mac = $nic.MACAddress
            }
        }
        catch {
            $row.status = 'error'
            $row.error = $_.Exception.Message
        }
        finally {
            if ($session) {
                Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue
            }
        }

        return $row
    }
}

process {
    foreach ($target in $ComputerName) {
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        Write-Verbose "Сбор: $target"
        $rows.Add((Get-Inventory -Target $target.Trim() -Cred $Credential))
    }
}

end {
    # при запуске через -File без конвейера блок process не вызывается,
    # поэтому список из параметра добирается здесь
    if ($rows.Count -eq 0) {
        foreach ($target in $ComputerName) {
            if ([string]::IsNullOrWhiteSpace($target)) { continue }
            Write-Verbose "Сбор: $target"
            $rows.Add((Get-Inventory -Target $target.Trim() -Cred $Credential))
        }
    }

    $rows |
        Sort-Object { $_.computer } |
        Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'

    $rows |
        Select-Object computer, status, os, ip, ram_gb, disk_c_free_pct, uptime_days |
        Format-Table -AutoSize

    Write-Host ("Записей: {0} → {1}" -f $rows.Count, $OutputPath)
}
