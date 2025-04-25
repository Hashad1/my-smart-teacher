# Script to create a clean repository without API keys or large files

Write-Host "Creating a clean repository without API keys or large files..." -ForegroundColor Yellow

# Create a temporary directory for the clean files
$tempDir = "clean-repo-temp"
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -Path $tempDir -ItemType Directory | Out-Null

# Copy only essential files, excluding large binaries and .git directory
Write-Host "Copying essential files..." -ForegroundColor Cyan
Get-ChildItem -Path . -Exclude ".git", "AzureCLI.msi", "frontend.zip", "tools/AzureCLI.msi", $tempDir | 
    Copy-Item -Destination $tempDir -Recurse -Force

# Remove the remove_api_keys.ps1 file since it might contain API keys
if (Test-Path "$tempDir/remove_api_keys.ps1") {
    Remove-Item -Path "$tempDir/remove_api_keys.ps1" -Force
}

# Create a new remove_api_keys.ps1 file with placeholders
$cleanRemoveApiKeysContent = @"
# Script to remove API keys from repository files

Write-Host "Removing API keys from repository files..." -ForegroundColor Yellow

# 1. Fix tools/deploy-apps.ps1
`$deployAppsPath = "tools/deploy-apps.ps1"
if (Test-Path `$deployAppsPath) {
    Write-Host "Processing `$deployAppsPath..." -ForegroundColor Cyan
    `$content = Get-Content `$deployAppsPath -Raw
    
    # Replace API keys with placeholders
    `$content = `$content -replace "YOUR_OPENAI_API_KEY", "`$env:OPENAI_API_KEY"
    `$content = `$content -replace "YOUR_GEMINI_API_KEY", "`$env:GEMINI_API_KEY"
    `$content = `$content -replace "YOUR_PINECONE_API_KEY", "`$env:PINECONE_API_KEY"
    
    # Save the modified content
    `$content | Set-Content `$deployAppsPath -NoNewline
    Write-Host "API keys removed from `$deployAppsPath" -ForegroundColor Green
}

# 2. Fix tools/deploy-db.ps1
`$deployDbPath = "tools/deploy-db.ps1"
if (Test-Path `$deployDbPath) {
    Write-Host "Processing `$deployDbPath..." -ForegroundColor Cyan
    `$content = Get-Content `$deployDbPath -Raw
    
    # Replace API keys with placeholders
    `$content = `$content -replace "YOUR_OPENAI_API_KEY", "`$env:OPENAI_API_KEY"
    `$content = `$content -replace "YOUR_ANTHROPIC_API_KEY", "`$env:ANTHROPIC_API_KEY"
    
    # Save the modified content
    `$content | Set-Content `$deployDbPath -NoNewline
    Write-Host "API keys removed from `$deployDbPath" -ForegroundColor Green
}

# 3. Fix docker-compose.yml
`$dockerComposePath = "docker-compose.yml"
if (Test-Path `$dockerComposePath) {
    Write-Host "Processing `$dockerComposePath..." -ForegroundColor Cyan
    `$content = Get-Content `$dockerComposePath -Raw
    
    # Replace API keys with placeholders
    `$content = `$content -replace "YOUR_AZURE_OPENAI_KEY", "`${OPENAI_API_KEY}"
    
    # Save the modified content
    `$content | Set-Content `$dockerComposePath -NoNewline
    Write-Host "API keys removed from `$dockerComposePath" -ForegroundColor Green
}

# 4. Fix python_service_enhanced/app.py
`$appPyPath = "python_service_enhanced/app.py"
if (Test-Path `$appPyPath) {
    Write-Host "Processing `$appPyPath..." -ForegroundColor Cyan
    `$content = Get-Content `$appPyPath -Raw
    
    # Replace API keys with placeholders
    `$content = `$content -replace "YOUR_AZURE_OPENAI_KEY", "os.environ.get('OPENAI_API_KEY', '')"
    
    # Save the modified content
    `$content | Set-Content `$appPyPath -NoNewline
    Write-Host "API keys removed from `$appPyPath" -ForegroundColor Green
}

Write-Host "`nAll API keys have been removed from the repository files." -ForegroundColor Green
"@

Set-Content -Path "$tempDir/remove_api_keys.ps1" -Value $cleanRemoveApiKeysContent

# Create a new .gitignore file
$gitignoreContent = @"
# Large files
AzureCLI.msi
frontend.zip
*.msi
*.zip
*.exe
*.dll
*.so
*.dylib

# Environment files with secrets
.env
.env.*
!.env.example

# API keys and secrets
**/secrets/

# Logs
*.log

# Database files
*.db
*.sqlite
*.sqlite3

# Cache directories
__pycache__/
*.py[cod]
*$py.class
.pytest_cache/
.coverage
htmlcov/
.tox/
.nox/
.hypothesis/
.egg-info/
.installed.cfg
*.egg

# Node modules
node_modules/
npm-debug.log
yarn-debug.log
yarn-error.log

# Build directories
dist/
build/
*.tsbuildinfo

# IDE files
.idea/
.vscode/
*.swp
*.swo
*~
"@

Set-Content -Path "$tempDir/.gitignore" -Value $gitignoreContent

# Initialize a new Git repository in the temp directory
Write-Host "Initializing a new Git repository..." -ForegroundColor Cyan
Set-Location -Path $tempDir
git init
git add .
git commit -m "Initial commit with clean files (no API keys or large binaries)"

# Add GitHub remote
Write-Host "Adding GitHub remote..." -ForegroundColor Cyan
git remote add origin https://github.com/Hashad1/my-smart-teacher.git

# Push to GitHub with force
Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
git push -f origin master:main

Write-Host "`nClean repository has been pushed to GitHub." -ForegroundColor Green
Write-Host "You can now delete this temporary directory and clone the clean repository." -ForegroundColor Cyan
Write-Host "cd .. && git clone https://github.com/Hashad1/my-smart-teacher.git my-smart-teacher-clean" -ForegroundColor White

# Return to the original directory
Set-Location -Path ..