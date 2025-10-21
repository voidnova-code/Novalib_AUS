param(
  [string]$VenvName = 'myenv'
)

# Get the project root directory (where this script is located)
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$venvPath = Join-Path $projectRoot $VenvName

Write-Host "Project root: $projectRoot"
Write-Host "Virtualenv path: $venvPath"

# Remove existing venv if present
if (Test-Path $venvPath) {
  Write-Host "Removing existing venv: $venvPath"
  try {
    Remove-Item -Recurse -Force -LiteralPath $venvPath
  } catch {
    Write-Error "Failed to remove venv. Close any programs using its files and retry."
    exit 1
  }
}

# Locate python
$pythonCmd = (Get-Command python -ErrorAction SilentlyContinue)?.Source
if (-not $pythonCmd) {
  $pythonCmd = (Get-Command python3 -ErrorAction SilentlyContinue)?.Source
}
if (-not $pythonCmd) {
  Write-Error "No 'python' or 'python3' found in PATH. Install Python or add it to PATH."
  exit 1
}

Write-Host "Using Python: $pythonCmd"

# Create virtualenv
Write-Host "Creating virtualenv..."
& $pythonCmd -m venv $venvPath
if ($LASTEXITCODE -ne 0) {
  Write-Error "Failed to create virtualenv."
  exit 1
}

$pyExe = Join-Path $venvPath 'Scripts\python.exe'

# Upgrade pip and install requirements if exist
Write-Host "Upgrading pip..."
& $pyExe -m pip install --upgrade pip setuptools wheel

$reqFile = Join-Path $projectRoot 'requirements.txt'
if (Test-Path $reqFile) {
  Write-Host "Installing from requirements.txt..."
  & $pyExe -m pip install -r $reqFile
} else {
  Write-Host "No requirements.txt found — skip installing dependencies."
}

Write-Host ""
Write-Host "Virtualenv recreated at: $venvPath"
Write-Host "Activate (PowerShell): .\\$VenvName\\Scripts\\Activate.ps1"
Write-Host "Activate (cmd): $VenvName\\Scripts\\activate.bat"
Write-Host "Then run: python manage.py runserver 10.88.206.108:8000"