param($Config, $Automated, $Headless)

$logFile = "$($Config.BaseDir)\Logs\Test-Environment.log"
function Write-Log {
    param($Message, $Level = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

function Invoke-Ollama {
    param($Prompt)
    try {
        $response = ollama run llama3:latest $Prompt 2>&1
        Write-Log "Ollama response: $response"
        return $response
    }
    catch {
        Write-Log "Ollama error: $_" "ERROR"
        return "Error: Could not communicate with Ollama."
    }
}

try {
    New-Item -ItemType Directory -Path (Split-Path $logFile -Parent) -Force | Out-Null
    Write-Log "Testing environment..."
    $checks = @(
        @{ Name = "Disk Space"; Test = { (Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace / 1GB -gt 1 }; ErrorMsg = "Not enough disk space on C: drive. You need at least 1GB free to safely run this process." },
        @{ Name = "Everything Search"; Test = { try { & $Config.EsPath -version; $true } catch { $false } }; ErrorMsg = "The 'es' tool is missing or not accessible. This tool helps find files quickly." },
        @{ Name = "Ollama"; Test = { try { ollama --version; $true } catch { $false } }; ErrorMsg = "Ollama is not installed or its service isn't running. It's used to provide helpful error messages." }
    )
    foreach ($check in $checks) {
        if (-not (& $check.Test)) {
            $errorMsg = "Check failed: $($check.Name) - $($check.ErrorMsg)"
            Write-Log $errorMsg "ERROR"
            $ollamaResponse = Invoke-Ollama "Error: $errorMsg. Suggest a simple fix for a beginner."
            if (-not $Automated -and -not $Headless) {
                Write-Host "$($ollamaResponse)"
                Write-Host "Continue anyway? (Y/N)"
                if ((Get-Host | Select-Object -ExpandProperty UI).RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -notmatch '^[Yy]$') {
                    return @{ Success = $false; Message = $errorMsg }
                }
            }
        }
    }
    Write-Log "Creating system restore point..."
    try {
        Checkpoint-Computer -Description "Pre-Cleanup Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "Restore point created"
        return @{ Success = $true; Message = "Environment tested and restore point created. Your system is ready for cleanup." }
    }
    catch {
        $errorMsg = "Failed to create restore point: $_"
        Write-Log $errorMsg "ERROR"
        $ollamaResponse = Invoke-Ollama "Error: $errorMsg. Explain in simple terms why this matters and if it's safe to continue."
        if (-not $Automated -and -not $Headless) {
            Write-Host "$($ollamaResponse)"
            Write-Host "Continue without restore point? (Y/N)"
            if ((Get-Host | Select-Object -ExpandProperty UI).RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -match '^[Yy]$') {
                return @{ Success = $true; Message = "Environment tested, but no restore point created. Proceeding with caution." }
            }
        }
        return @{ Success = $false; Message = $errorMsg }
    }
}
catch {
    Write-Log "Unexpected error: $_" "ERROR"
    return @{ Success = $false; Message = "Environment test failed: $_" }
}