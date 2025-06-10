param($Config, $Automated, $Headless, $SpaceFreed)

$logFile = "$($Config.BaseDir)\Logs\Verify-Space.log"
function Write-Log {
    param($Message, $Level = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

try {
    New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force | Out-Null
    Write-Log "Verifying disk space..."
    $drive = (Get-Location).Drive.Name + ":"
    $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$drive'" | Select-Object FreeSpace
    $currentFreeSpace = $disk.FreeSpace / 1MB
    Write-Log "Current free space on $drive: $currentFreeSpace MB"
    $msg = "Checked how much space is free on your drive after cleanup. Expected to free $SpaceFreed MB, now you have $currentFreeSpace MB free."
    return @{ Success = $true; Message = $msg }
}
catch {
    Write-Log "Error verifying disk space: $_" "ERROR"
    return @{ Success = $false; Message = "Couldn't check free disk space due to an error. Check the log at $logFile." }
}