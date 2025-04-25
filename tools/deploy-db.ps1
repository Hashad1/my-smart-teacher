# Azure Database Deployment Script for My Smart Teacher Project
# This script creates PostgreSQL and Cosmos DB databases on Azure

param (
    [string]$ResourceGroup = "my-smart-teacher-rg",
    [string]$Location = "uaenorth",
    [string]$PostgresServerName = "my-smart-teacher-pg",
    [string]$PostgresAdminUser = "mstadmin",
    [string]$PostgresDBName = "my_smart_teacher",
    [string]$CosmosAccountName = "my-smart-teacher-cosmos",
    [string]$CosmosDBName = "my_smart_teacher",
    [string]$CosmosCollectionName = "model_usage_stats",
    [switch]$EnablePublicAccess
)

# Request password
$securePassword = Read-Host "Enter PostgreSQL admin password" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$PostgresPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Check Azure login
try {
    $account = az account show | ConvertFrom-Json
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
}
catch {
    Write-Host "Not logged in to Azure. Please login first." -ForegroundColor Red
    az login
}

# Check resource group existence
$exists = az group exists --name $ResourceGroup
if ($exists -eq "true") {
    Write-Host "Resource group '$ResourceGroup' already exists." -ForegroundColor Green
}
else {
    Write-Host "Creating resource group '$ResourceGroup' in location '$Location'..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location
}

# Create PostgreSQL server
Write-Host "`n===== Creating PostgreSQL Database =====" -ForegroundColor Cyan
$serverExists = az postgres flexible-server show --name $PostgresServerName --resource-group $ResourceGroup 2>$null
if ($null -ne $serverExists) {
    Write-Host "PostgreSQL server '$PostgresServerName' already exists." -ForegroundColor Green
}
else {
    Write-Host "Creating PostgreSQL server '$PostgresServerName'..." -ForegroundColor Yellow
    
    # Create flexible PostgreSQL server
    az postgres flexible-server create `
        --name $PostgresServerName `
        --resource-group $ResourceGroup `
        --location $Location `
        --admin-user $PostgresAdminUser `
        --admin-password $PostgresPassword `
        --sku-name Standard_B1ms `
        --tier Burstable `
        --storage-size 32 `
        --version 14 `
        --high-availability Disabled
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create PostgreSQL server." -ForegroundColor Red
        exit 1
    }
}

# Create PostgreSQL database
Write-Host "Creating PostgreSQL database '$PostgresDBName'..." -ForegroundColor Yellow
az postgres flexible-server db create `
    --resource-group $ResourceGroup `
    --server-name $PostgresServerName `
    --database-name $PostgresDBName

# Add firewall rules if public access is enabled
if ($EnablePublicAccess) {
    Write-Host "Adding firewall rule to allow access from Azure services..." -ForegroundColor Yellow
    az postgres flexible-server firewall-rule create `
        --resource-group $ResourceGroup `
        --name $PostgresServerName `
        --rule-name AllowAzureServices `
        --start-ip-address 0.0.0.0 `
        --end-ip-address 0.0.0.0
}

# Create Cosmos DB account
Write-Host "`n===== Creating Cosmos DB (MongoDB) =====" -ForegroundColor Cyan
$accountExists = az cosmosdb check-name-exists --name $CosmosAccountName
if ($accountExists -eq "true") {
    Write-Host "Cosmos DB account '$CosmosAccountName' already exists." -ForegroundColor Green
}
else {
    Write-Host "Creating Cosmos DB account '$CosmosAccountName' with MongoDB API..." -ForegroundColor Yellow
    
    # Create Cosmos DB account with MongoDB interface
    az cosmosdb create `
        --name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --kind MongoDB `
        --capabilities EnableMongo `
        --default-consistency-level Session `
        --locations regionName=$Location failoverPriority=0 isZoneRedundant=False
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create Cosmos DB account." -ForegroundColor Red
        exit 1
    }
}

# Create MongoDB database
Write-Host "Creating MongoDB database '$CosmosDBName'..." -ForegroundColor Yellow
az cosmosdb mongodb database create `
    --account-name $CosmosAccountName `
    --resource-group $ResourceGroup `
    --name $CosmosDBName

# Create MongoDB collection
Write-Host "Creating MongoDB collection '$CosmosCollectionName'..." -ForegroundColor Yellow
az cosmosdb mongodb collection create `
    --account-name $CosmosAccountName `
    --resource-group $ResourceGroup `
    --database-name $CosmosDBName `
    --name $CosmosCollectionName `
    --shard "model" `
    --throughput 400

# Get connection information
Write-Host "`n===== Getting Connection Information =====" -ForegroundColor Cyan

# PostgreSQL information
$PostgresFQDN = "$PostgresServerName.postgres.database.azure.com"

# Cosmos DB information
$CosmosKeys = az cosmosdb keys list --name $CosmosAccountName --resource-group $ResourceGroup | ConvertFrom-Json
$CosmosPrimaryKey = $CosmosKeys.primaryMasterKey

# Build connection strings safely
$PostgresConnectionString = "postgres://${PostgresAdminUser}:${PostgresPassword}@${PostgresFQDN}:5432/${PostgresDBName}"
$CosmosConnectionString = "mongodb://${CosmosAccountName}:${CosmosPrimaryKey}@${CosmosAccountName}.mongo.cosmos.azure.com:10255/${CosmosDBName}?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${CosmosAccountName}@"

# Create .env file
$envContent = @"
# PostgreSQL Database Variables
DB_HOST=$PostgresFQDN
DB_PORT=5432
DB_USER=$PostgresAdminUser
DB_PASSWORD=$PostgresPassword
DB_NAME=$PostgresDBName
DATABASE_URL=$PostgresConnectionString

# MongoDB Database Variables
MONGO_URI=$CosmosConnectionString
MONGODB_URI=$CosmosConnectionString

# Application Environment Variables
NODE_ENV=production
PORT=3001
JWT_SECRET=4b7101ffd4fc47f3009d1f66c554b459e41fce59766eb244dad9d813a0f5faed8f02962a2cee141e94268083993c834cadb3f8ca624f8620c569bca91fd40e1095b2dcad0bae5bb151be2e09480bed4fd2c4b96f3ab69e86ccbfdc9d082ead99e0b952739a19ff57794b386c3ad85bd57d5c31edfc0aae18e4e644ce31f90115145967e6ab4e1fa16baef22bbe32aadad5af89269d02ad05f7a666e0b1d8ad40f2291ca55cf9da99c2220340c9e7899659fe6dd79098849bd32e750a0bdc5c1095fff4d66db9bb7648b49442cc8040bd717f126ba21c3979c32ad3c0abf678d0ffea1686b8ea7243a8349b420401dd46c3d650ba934639f6110628bb11986558
ENABLE_AI_FEATURES=true
ENABLE_FALLBACK=true
MAX_DAILY_TOKENS=100000
MAX_MONTHLY_TOKENS=3000000

# AI API Keys Variables
OPENAI_API_KEY=$env:OPENAI_API_KEY
GOOGLE_AI_API_KEY=your_google_ai_api_key_here
GROQ_API_KEY=$env:GROQ_API_KEY
ANTHROPIC_API_KEY=$env:ANTHROPIC_API_KEY

# Security Variables
CRYPTO_SECRET_KEY=your_crypto_secret_key_here
CRYPTO_IV=your_crypto_iv_here
"@

$envPath = Join-Path -Path (Get-Location) -ChildPath ".env.azure"
$envContent | Out-File -FilePath $envPath -Encoding utf8

Write-Host "Created .env.azure file at: $envPath" -ForegroundColor Green

# Display connection information
Write-Host "`n===== Database Connection Information =====" -ForegroundColor Cyan
Write-Host "PostgreSQL FQDN: $PostgresFQDN" -ForegroundColor Yellow
Write-Host "MongoDB Account: $CosmosAccountName.mongo.cosmos.azure.com" -ForegroundColor Yellow

Write-Host "`n✅ Databases created successfully!" -ForegroundColor Green
Write-Host "You can use the .env.azure file to configure your application to connect to the databases." -ForegroundColor Green

# Additional instructions
Write-Host "`n===== Next Steps =====" -ForegroundColor Cyan
Write-Host "1. Copy the .env.azure file to your backend application directory" -ForegroundColor White
Write-Host "2. Update environment variables in your Container App" -ForegroundColor White
Write-Host "3. Run migrations to create tables in PostgreSQL database" -ForegroundColor White

# Display information about repositories and services
Write-Host "`n===== Supported Repositories and Services =====" -ForegroundColor Cyan
Write-Host "Repositories:" -ForegroundColor White
Write-Host "- ModelFallbackLogRepository: Handles model switching logs" -ForegroundColor White
Write-Host "- AiModelConfigRepository: Manages AI model configurations" -ForegroundColor White
Write-Host "- PromptTemplateRepository: Manages prompt templates" -ForegroundColor White
Write-Host "- PromptLibraryImportRepository: Handles prompt library import records" -ForegroundColor White
Write-Host "- ModelUsageStatsRepository: Manages model usage statistics in MongoDB" -ForegroundColor White
Write-Host "- AiTeacherRepository: Manages AI teachers" -ForegroundColor White

Write-Host "`nServices:" -ForegroundColor White
Write-Host "- ApiKeyService: Comprehensive service for API key management" -ForegroundColor White
Write-Host "- CryptoService: Service for encryption and decryption" -ForegroundColor White
Write-Host "- SystemSettingService: Service for system settings management" -ForegroundColor White
Write-Host "- AiModelConfigService: Service for AI model configuration management" -ForegroundColor White
Write-Host "- PromptTemplateService: Service for prompt template management" -ForegroundColor White
Write-Host "- ModelUsageStatsService: Service for model usage statistics management and analysis" -ForegroundColor White
