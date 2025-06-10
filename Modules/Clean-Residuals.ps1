param($Config, $Automated, $Headless, $Residuals)

$logFile = "$($Config.BaseDir)\Logs\Clean-Residuals.log"
function Write-Log {
    param($Message, $Level = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Backup-Item {
    param($Path)
    $backupPath = "$($Config.BaseDir)\Backups\Folder-$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    try {
        New-Item -ItemType Directory -Path (Split-Path $backupPath -Parent) -Force | Out-Null
        Compress-Archive -Path $Path -DestinationPath $backupPath -Force -ErrorAction Stop
        Write-Log "Backed up folder: $Path to $backupPath"
        return $true
    }
    catch {
        Write-Log "Failed to backup folder at $Path: $_" "ERROR"
        return $false
    }
}

try {
    New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force | Out-Null
    if (-not $Residuals) {
        Write-Log "No residual data provided" "ERROR"
        return @{ Success = $false; Message = "Need to scan for leftover folders first before cleaning them." }
    }
    Write-Log "Cleaning residuals..."
    $spaceFreed = 0
    foreach ($item in $Residuals) {
        $remove = $Automated
        if (-not $Automated -and -not $Headless) {
            Write-Host "Folder: $($item.Path)"
            Write-Host "Size: $($item.SizeMB) MB, Last Modified: $($item.LastModified)"
            Write-Host "Remove? (Y/N)"
            $response = (Get-Host | Select-Object -ExpandProperty UI).RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
            $remove = $response -match '^[Yy]$'
        }
        if ($remove) {
            if (Backup-Item -Path $item.Path) {
                try {
                    $initialSize = (Get-ChildItem -Path $item.Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                    Remove-Item -Path $item.Path -Recurse -Force -ErrorAction Stop
                    Write-Log "Removed folder: $($item.Path)"
                    $spaceFreed += $initialSize / 1MB
                }
                catch {
                    Write-Log "Failed to remove folder $($item.Path): $_" "ERROR"
                }
            }
        }
        else {
            Write-Log "Skipped folder: $($item.Path)"
        }
    }
    return @{ Success = $true; Message = "Cleaned up leftover folders, freeing $spaceFreed MB of disk space."; SpaceFreed = $spaceFreed }
}
catch {
    Write-Log "Error cleaning residuals: $_" "ERROR"
    return @{ Success = $false; Message = "Couldn't clean up leftover folders due to an error. Check the log at $logFile." }
}