# Script to remove API keys from repository files

Write-Host "Removing API keys from repository files..." -ForegroundColor Yellow

# 1. Fix tools/deploy-apps.ps1
$deployAppsPath = "tools/deploy-apps.ps1"
if (Test-Path $deployAppsPath) {
    Write-Host "Processing $deployAppsPath..." -ForegroundColor Cyan
    $content = Get-Content $deployAppsPath -Raw
    
    # Replace API keys with placeholders
    $content = $content -replace "YOUR_OPENAI_API_KEY", "$env:OPENAI_API_KEY"
    $content = $content -replace "YOUR_GEMINI_API_KEY", "$env:GEMINI_API_KEY"
    $content = $content -replace "YOUR_PINECONE_API_KEY", "$env:PINECONE_API_KEY"
    
    # Save the modified content
    $content | Set-Content $deployAppsPath -NoNewline
    Write-Host "API keys removed from $deployAppsPath" -ForegroundColor Green
}

# 2. Fix tools/deploy-db.ps1
$deployDbPath = "tools/deploy-db.ps1"
if (Test-Path $deployDbPath) {
    Write-Host "Processing $deployDbPath..." -ForegroundColor Cyan
    $content = Get-Content $deployDbPath -Raw
    
    # Replace API keys with placeholders
    $content = $content -replace "YOUR_OPENAI_API_KEY", "$env:OPENAI_API_KEY"
    $content = $content -replace "YOUR_ANTHROPIC_API_KEY", "$env:ANTHROPIC_API_KEY"
    
    # Save the modified content
    $content | Set-Content $deployDbPath -NoNewline
    Write-Host "API keys removed from $deployDbPath" -ForegroundColor Green
}

# 3. Fix docker-compose.yml
$dockerComposePath = "docker-compose.yml"
if (Test-Path $dockerComposePath) {
    Write-Host "Processing $dockerComposePath..." -ForegroundColor Cyan
    $content = Get-Content $dockerComposePath -Raw
    
    # Replace API keys with placeholders
    $content = $content -replace "YOUR_AZURE_OPENAI_KEY", "${OPENAI_API_KEY}"
    
    # Save the modified content
    $content | Set-Content $dockerComposePath -NoNewline
    Write-Host "API keys removed from $dockerComposePath" -ForegroundColor Green
}

# 4. Fix python_service_enhanced/app.py
$appPyPath = "python_service_enhanced/app.py"
if (Test-Path $appPyPath) {
    Write-Host "Processing $appPyPath..." -ForegroundColor Cyan
    $content = Get-Content $appPyPath -Raw
    
    # Replace API keys with placeholders
    $content = $content -replace "YOUR_AZURE_OPENAI_KEY", "os.environ.get('OPENAI_API_KEY', '')"
    
    # Save the modified content
    $content | Set-Content $appPyPath -NoNewline
    Write-Host "API keys removed from $appPyPath" -ForegroundColor Green
}

Write-Host "
All API keys have been removed from the repository files." -ForegroundColor Green
