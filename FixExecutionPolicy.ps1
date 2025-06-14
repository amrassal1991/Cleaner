#Requires -RunAsAdministrator

# Initialize log file
$logFile = "$env:TEMP\FixExecutionPolicy_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
function Write-Log {
    param($Message, $Level = "INFO")
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level]: $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

# Function to test script execution
function Test-ScriptExecution {
    param($ScriptPath)
    try {
        Write-Log "Attempting to run $ScriptPath..."
        & $ScriptPath -ErrorAction Stop
        Write-Log "Script executed successfully!"
        return $true
    }
    catch {
        Write-Log "Failed to run script: $_" "ERROR"
        return $false
    }
}

# Function to restart terminal
function Restart-Terminal {
    Write-Log "Restarting PowerShell terminal..."
    Start-Process powershell -Verb RunAs -ArgumentList "-NoExit -Command cd '$PWD'"
    exit
}

# Main resolution methods
$methods = @(
    @{
        Name = "Set RemoteSigned for CurrentUser"
        Command = { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue }
        Verify = { (Get-ExecutionPolicy -Scope CurrentUser) -eq "RemoteSigned" }
    },
    @{
        Name = "Set Bypass for CurrentUser"
        Command = { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue }
        Verify = { (Get-ExecutionPolicy -Scope CurrentUser) -eq "Bypass" }
    },
    @{
        Name = "Set Unrestricted for CurrentUser"
        Command = { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Force -ErrorAction SilentlyContinue }
        Verify = { (Get-ExecutionPolicy -Scope CurrentUser) -eq "Unrestricted" }
    },
    @{
        Name = "Set RemoteSigned for LocalMachine"
        Command = { Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction SilentlyContinue }
        Verify = { (Get-ExecutionPolicy -Scope LocalMachine) -eq "RemoteSigned" }
    }
)

# Main process
Write-Log "Starting execution policy fix process..."
$scriptPath = ".\CleanResidualApps.ps1"

if (!(Test-Path $scriptPath)) {
    Write-Log "Script $scriptPath not found in current directory!" "ERROR"
    Write-Host "Please ensure CleanResidualApps.ps1 is in $PWD" -ForegroundColor Red
    exit
}

foreach ($method in $methods) {
    Write-Log "Trying method: $($method.Name)"
    try {
        & $method.Command
        if (& $method.Verify) {
            Write-Log "Successfully applied $($method.Name)"
            if (Test-ScriptExecution -ScriptPath $scriptPath) {
                Write-Log "Execution policy fixed. Restarting terminal..."
                Restart-Terminal
                break
            }
            else {
                Write-Log "Script still cannot run after applying $($method.Name)" "WARNING"
            }
        }
        else {
            Write-Log "Failed to verify $($method.Name)" "ERROR"
        }
    }
    catch {
        Write-Log "Error applying $($method.Name): $_" "ERROR"
    }
}

Write-Log "All methods failed to resolve the issue" "ERROR"
Write-Host "Could not resolve execution policy issue. Check log at $logFile" -ForegroundColor Red
Write-Host "Try running PowerShell as Administrator or check https://go.microsoft.com/fwlink/?LinkID=135170" -ForegroundColor Yellow