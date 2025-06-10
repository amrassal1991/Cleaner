param($Config, $Automated, $Headless)

$logFile = "$($Config.BaseDir)\Logs\Analyze-Files.log"
$jsonOutput = "$($Config.BaseDir)\Reports\FileAnalysis.json"
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
    Write-Log "Analyzing files in $($Config.UserProfile)..."
    $results = @{}
    $installedPrograms = Get-InstalledPrograms
    $totalSize = 0
    $files = Get-ChildItem -Path $Config.UserProfile -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $ext = $file.Extension.ToLower()
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        $totalSize += $sizeMB
        if (-not $results.ContainsKey($ext)) {
            $results[$ext] = @{ Count = 0; SizeMB = 0; Files = @() }
        }
        $results[$ext].Count += 1
        $results[$ext].SizeMB += $sizeMB
        $isStandalone = $true
        $parentFolder = [System.IO.Path]::GetFileName($file.DirectoryName).ToLower()
        foreach ($program in $installedPrograms) {
            if ($parentFolder -like "*$program*") {
                $isStandalone = $false
                break
            }
        }
        $results[$ext].Files += [PSCustomObject]@{
            Path         = $file.FullName
            SizeMB       = $sizeMB
            LastModified = $file.LastWriteTime
            Standalone   = $isStandalone
        }
    }
    $results["TotalSizeMB"] = $totalSize
    $results | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonOutput -Encoding UTF8
    Write-Log "Analysis saved to $jsonOutput"
    return @{ Success = $true; Message = "Scanned your files to find out what types you have (like PDFs or images) and how much space they use. Found $totalSize MB of files."; Data = $results }
}
catch {
    Write-Log "Error analyzing files: $_" "ERROR"
    return @{ Success = $false; Message = "Couldn't scan your files due to an error. Check the log at $logFile for details." }
}