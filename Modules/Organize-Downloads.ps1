param($Config, $Automated, $Headless, $Analysis)

$logFile = "$($Config.BaseDir)\Logs\Organize-Downloads.log"
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
        return @{ Success = $false; Message = "Need to scan files first before organizing Downloads." }
    }
    Write-Log "Organizing Downloads folder..."
    $exeFolder = "$($Config.UserProfile)\Downloads\Executables"
    $zipFolder = "$($Config.UserProfile)\Downloads\Compressed"
    $movedFiles = @{ $exeFolder = @(); $zipFolder = @() }
    $duplicates = @()
    if (-not (Test-Path $exeFolder)) { New-Item -ItemType Directory -Path $exeFolder -Force | Out-Null }
    if (-not (Test-Path $zipFolder)) { New-Item -ItemType Directory -Path $zipFolder -Force | Out-Null }

    $exeFiles = $Analysis[".exe"], $Analysis[".msi"] | Where-Object { $_ } | ForEach-Object { $_.Files }
    $zipFiles = $Analysis[".zip"], $Analysis[".rar"], $Analysis[".7z"] | Where-Object { $_ } | ForEach-Object { $_.Files }

    foreach ($file in $exeFiles) {
        if (-not $file.Standalone) { continue }
        if (Backup-Item -Path $file.Path) {
            try {
                Move-Item -Path $file.Path -Destination $exeFolder -Force -ErrorAction Stop
                Write-Log "Moved executable: $($file.Path) to $exeFolder"
                $movedFiles[$exeFolder] += $file.Path
            }
            catch {
                Write-Log "Failed to move executable $($file.Path): $_" "ERROR"
            }
        }
    }

    foreach ($file in $zipFiles) {
        if (-not $file.Standalone) { continue }
        if (Backup-Item -Path $file.Path) {
            try {
                Move-Item -Path $file.Path -Destination $zipFolder -Force -ErrorAction Stop
                Write-Log "Moved compressed file: $($file.Path) to $zipFolder"
                $movedFiles[$zipFolder] += $file.Path
            }
            catch {
                Write-Log "Failed to move compressed file $($file.Path): $_" "ERROR"
            }
        }
    }

    $exeNames = $exeFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Path) }
    $zipNames = $zipFiles | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Path) }
    foreach ($exe in $exeNames) {
        $pattern = [regex]::Escape($exe) -replace "(-v?\d+\.\d+\.\d+)", "(-v?\d+\.\d+\.\d+)?$"
        foreach ($zip in $zipNames) {
            if ($zip -match $pattern) {
                $duplicates += [PSCustomObject]@{
                    Exe = $exe
                    Zip = $zip
                }
            }
        }
    }

    if ($duplicates) {
        foreach ($dup in $duplicates) {
            $zipPath = $zipFiles | Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Path) -eq $dup.Zip } | Select-Object -ExpandProperty Path
            if ($zipPath) {
                $remove = $Automated
                if (-not $Automated -and -not $Headless) {
                    Write-Host "Found similar files: $($dup.Exe) (executable) and $($dup.Zip) (compressed)"
                    Write-Host "Remove the compressed file? (Y/N)"
                    $response = (Get-Host | Select-Object -ExpandProperty UI).RawUI.ReadKey("NoEcho,IncludeKeyDown").Character
                    $remove = $response -match '^[Yy]$'
                }
                if ($remove -and (Backup-Item -Path $zipPath)) {
                    try {
                        Remove-Item -Path $zipPath -Force -ErrorAction Stop
                        Write-Log "Removed duplicate compressed file: $zipPath"
                    }
                    catch {
                        Write-Log "Failed to remove duplicate $zipPath: $_" "ERROR"
                    }
                }
            }
        }
    }

    $msg = "Sorted files in your Downloads folder into Executables and Compressed folders, and removed duplicate files."
    return @{ Success = $true; Message = $msg; Data = $movedFiles }
}
catch {
    Write-Log "Error organizing Downloads: $_" "ERROR"
    return @{ Success = $false; Message = "Couldn't organize Downloads due to an error. Check the log at $logFile." }
}