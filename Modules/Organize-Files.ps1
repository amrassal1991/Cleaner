param($Config, $Automated, $Headless, $Analysis)

$logFile = "$($Config.BaseDir)\Logs\Organize-Files.log"
function Write-Log {
    param($Message, $Level = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Backup-Item {
    param($Path)
    $backupPath = "$($Config.BaseDir)\Backups\File-$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
    try {
        New-Item -ItemType Directory -Path (Split-Path $backupPath -Parent) -Force | Out-Null
        Compress-Archive -Path $Path -DestinationPath $backupPath -Force -ErrorAction Stop
        Write-Log "Backed up file: $Path to $backupPath"
        return $true
    }
    catch {
        Write-Log "Failed to backup file at $Path: $_" "ERROR"
        return $false
    }
}

try {
    New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force | Out-Null
    if (-not $Analysis) {
        Write-Log "No file analysis data provided" "ERROR"
        return @{ Success = $false; Message = "Need to scan files first before organizing them." }
    }
    Write-Log "Organizing standalone files..."
    $destFolders = $Config.DestFolders
    $movedFiles = @{}
    $spaceMoved = 0
    foreach ($ext in $Analysis.Keys) {
        if ($ext -eq "TotalSizeMB") { continue }
        $targetFolder = $null
        foreach ($key in $destFolders.PSObject.Properties.Name) {
            if ($ext -in ($key -split ',')) {
                $targetFolder = Invoke-Expression $destFolders.$key
                break
            }
        }
        if (-not $targetFolder) { $targetFolder = "$($Config.UserProfile)\Downloads\Other" }
        if (-not (Test-Path $targetFolder)) { New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null }
        $movedFiles[$targetFolder] = @()

        foreach ($file in $Analysis[$ext].Files) {
            if (-not $file.Standalone) { continue }
            $move = $Automated
            if (-not $Automated -and -not $Headless) {
                Write-Host "File: $($file.Path)"
                Write-Host "Size: $($file.SizeMB) MB, Last Modified: $($file.LastModified)"
                Write-Host "Move to: $targetFolder"
                Write-Host "Move? (Y/N)"
                $response = (Get-Host | Select-Object -ExpandProperty UI).RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
                $move = $response -match '^[Yy]$'
            }
            if ($move) {
                if (Backup-Item -Path $file.Path) {
                    try {
                        Move-Item -Path $file.Path -Destination $targetFolder -Force -ErrorAction Stop
                        Write-Log "Moved file: $($file.Path) to $targetFolder"
                        $movedFiles[$targetFolder] += $file.Path
                        $spaceMoved += $file.SizeMB
                    }
                    catch {
                        Write-Log "Failed to move file $($file.Path): $_" "ERROR"
                    }
                }
            }
            else {
                Write-Log "Skipped file: $($file.Path)"
            }
        }
    }
    $msg = "Organized your files by moving them to folders like Documents or Pictures. Moved $spaceMoved MB of files."
    return @{ Success = $true; Message = $msg; Data = $movedFiles }
}
catch {
    Write-Log "Error organizing files: $_" "ERROR"
    return @{ Success = $false; Message = "Couldn't organize files due to an error. Check the log at $logFile." }
}