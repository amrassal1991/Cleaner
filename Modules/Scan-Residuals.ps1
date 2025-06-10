param($Config, $Automated, $Headless)

$logFile = "$($Config.BaseDir)\Logs\Scan-Residuals.log"
$jsonOutput = "$($Config.BaseDir)\Reports\ResidualScan.json"
function Write-Log {
    param($Message, $Level = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Get-InstalledPrograms {
    $programs = @()
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($path in $regPaths) {
        try {
            $keys = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
            $programs += $keys | Where-Object { $_.DisplayName } | Select-Object -ExpandProperty DisplayName
        }
        catch {
            Write-Log "Error accessing registry path $path: $_" "ERROR"
        }
    }
    return $programs | ForEach-Object { $_.ToLower() }
}

try {
    New-Item -ItemType Directory -Path (Split-Path $logFile -Parent), (Split-Path $jsonOutput -Parent) -Force | Out-Null
    Write-Log "Scanning residuals..."
    $results = @()
    $totalSize = 0
    $installedPrograms = Get-InstalledPrograms
    foreach ($path in $Config.Paths) {
        $path = Invoke-Expression $path
        $esCommand = "& $($Config.EsPath) -path '$path' -size -date-modified -csv"
        $output = Invoke-Expression $esCommand | ConvertFrom-Csv
        foreach ($item in $output) {
            if ($item.'Attributes' -notlike '*D*') { continue }
            $folderNameLower = [System.IO.Path]::GetFileName($item.'Name').ToLower()
            $isResidual = $true
            foreach ($program in $installedPrograms) {
                if ($folderNameLower -like "*$program*") {
                    $isResidual = $false
                    break
                }
            }
            if ($isResidual) {
                $sizeMB = [math]::Round([int64]$item.'Size' / 1MB, 2)
                $totalSize += $sizeMB
                $results += [PSCustomObject]@{
                    Path        = $item.'Name'
                    SizeMB      = $sizeMB
                    LastModified = $item.'Date Modified'
                }
            }
        }
    }
    $results | ConvertTo-Json | Out-File -FilePath $jsonOutput -Encoding UTF8
    Write-Log "Residual scan saved to $jsonOutput"
    return @{ Success = $true; Message = "Found leftover folders from old programs, totaling $totalSize MB, that can be safely removed."; Data = $results; SpaceFreed = $totalSize }
}
catch {
    Write-Log "Error scanning residuals: $_" "ERROR"
    return @{ Success = $false; Message = "Couldn't scan for leftover folders due to an error. Check the log at $logFile." }
}