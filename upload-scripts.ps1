param (
    [string]$FolderPath,   # Full path to the folder containing PowerShell scripts
    [string]$RepoName,     # Name of the new GitHub repository
    [switch]$Private       # Optional switch to make the repository private
)

# Check if gh is installed
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Please install it first."
    exit 1
}

# Authenticate if not already logged in
if (-not (gh auth status | Select-String "Logged in to github.com")) {
    gh auth login
}

# Navigate to the folder
Set-Location -Path $FolderPath

# Initialize Git if not already a repository
if (-not (Test-Path .git)) {
    git init
}

# Add all files
git add .

# Commit the files
git commit -m "Initial commit of PowerShell scripts"

# Determine visibility
$visibility = if ($Private) { "--private" } else { "--public" }

# Create the GitHub repository and push the local repository
gh repo create $RepoName $visibility --source=.