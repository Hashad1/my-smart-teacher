#!/usr/bin/env pwsh
# سكريبت إعداد قواعد البيانات على Azure لمشروع معلمي الذكي

param (
    [string]$ResourceGroup = "my-smart-teacher-rg",
    [string]$Location = "uaenorth",
    [string]$PostgresServerName = "my-smart-teacher-postgres",
    [string]$PostgresAdminUser = "mstadmin",
    [string]$PostgresAdminPassword = "",
    [string]$PostgresDBName = "my_smart_teacher",
    [string]$CosmosAccountName = "my-smart-teacher-cosmos",
    [string]$CosmosDBName = "my_smart_teacher",
    [string]$CosmosCollectionName = "model_usage_stats",
    [bool]$CreateFirewallRules = $true,
    [bool]$EnablePublicAccess = $false
)

# التحقق من تسجيل الدخول إلى Azure
function Test-AzureLogin {
    try {
        $account = az account show | ConvertFrom-Json
        Write-Host "تم تسجيل الدخول كـ: $($account.user.name)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "لم يتم تسجيل الدخول إلى Azure. الرجاء تسجيل الدخول أولاً." -ForegroundColor Red
        az login
        return $false
    }
}

# التحقق من وجود مجموعة الموارد
function Test-ResourceGroup {
    param (
        [string]$ResourceGroup
    )
    
    $exists = az group exists --name $ResourceGroup
    if ($exists -eq "true") {
        Write-Host "مجموعة الموارد '$ResourceGroup' موجودة بالفعل." -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "إنشاء مجموعة الموارد '$ResourceGroup' في الموقع '$Location'..." -ForegroundColor Yellow
        az group create --name $ResourceGroup --location $Location
        return $true
    }
}

# إنشاء خادم PostgreSQL
function New-PostgreSQLServer {
    param (
        [string]$ResourceGroup,
        [string]$ServerName,
        [string]$Location,
        [string]$AdminUser,
        [string]$AdminPassword,
        [string]$DBName,
        [bool]$CreateFirewallRules,
        [bool]$EnablePublicAccess
    )
    
    # التحقق من كلمة المرور
    if ([string]::IsNullOrEmpty($AdminPassword)) {
        $AdminPassword = Read-Host "أدخل كلمة مرور مشرف PostgreSQL" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
        $AdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    
    # التحقق من وجود الخادم
    $serverExists = az postgres flexible-server show --name $ServerName --resource-group $ResourceGroup 2>$null
    
    if ($serverExists) {
        Write-Host "خادم PostgreSQL '$ServerName' موجود بالفعل." -ForegroundColor Green
    }
    else {
        Write-Host "إنشاء خادم PostgreSQL '$ServerName'..." -ForegroundColor Yellow
        
        # إنشاء خادم PostgreSQL المرن
        az postgres flexible-server create `
            --name $ServerName `
            --resource-group $ResourceGroup `
            --location $Location `
            --admin-user $AdminUser `
            --admin-password $AdminPassword `
            --sku-name Standard_B1ms `
            --tier Burstable `
            --storage-size 32 `
            --version 14 `
            --high-availability Disabled `
            --public-access $EnablePublicAccess
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "فشل في إنشاء خادم PostgreSQL." -ForegroundColor Red
            return $false
        }
    }
    
    # إنشاء قاعدة البيانات
    Write-Host "إنشاء قاعدة بيانات PostgreSQL '$DBName'..." -ForegroundColor Yellow
    az postgres flexible-server db create `
        --resource-group $ResourceGroup `
        --server-name $ServerName `
        --database-name $DBName
    
    # إضافة قواعد جدار الحماية إذا تم تمكين الوصول العام
    if ($CreateFirewallRules -and $EnablePublicAccess) {
        Write-Host "إضافة قاعدة جدار الحماية للسماح بالوصول من أي مكان..." -ForegroundColor Yellow
        az postgres flexible-server firewall-rule create `
            --resource-group $ResourceGroup `
            --name $ServerName `
            --rule-name AllowAll `
            --start-ip-address 0.0.0.0 `
            --end-ip-address 255.255.255.255
        
        # إضافة قاعدة جدار الحماية للسماح بالوصول من خدمات Azure
        Write-Host "إضافة قاعدة جدار الحماية للسماح بالوصول من خدمات Azure..." -ForegroundColor Yellow
        az postgres flexible-server firewall-rule create `
            --resource-group $ResourceGroup `
            --name $ServerName `
            --rule-name AllowAzureServices `
            --start-ip-address 0.0.0.0 `
            --end-ip-address 0.0.0.0
    }
    
    # الحصول على سلسلة الاتصال
    $connectionString = "postgres://$AdminUser:$AdminPassword@$ServerName.postgres.database.azure.com:5432/$DBName"
    
    return @{
        ServerName = $ServerName
        DatabaseName = $DBName
        ConnectionString = $connectionString
        AdminUser = $AdminUser
        AdminPassword = $AdminPassword
        FQDN = "$ServerName.postgres.database.azure.com"
    }
}

# إنشاء حساب Cosmos DB مع واجهة MongoDB
function New-CosmosDBAccount {
    param (
        [string]$ResourceGroup,
        [string]$AccountName,
        [string]$Location,
        [string]$DBName,
        [string]$CollectionName
    )
    
    # التحقق من وجود حساب Cosmos DB
    $accountExists = az cosmosdb check-name-exists --name $AccountName
    
    if ($accountExists -eq "true") {
        Write-Host "حساب Cosmos DB '$AccountName' موجود بالفعل." -ForegroundColor Green
    }
    else {
        Write-Host "إنشاء حساب Cosmos DB '$AccountName' مع واجهة MongoDB API..." -ForegroundColor Yellow
        
        # إنشاء حساب Cosmos DB مع واجهة MongoDB
        az cosmosdb create `
            --name $AccountName `
            --resource-group $ResourceGroup `
            --kind MongoDB `
            --capabilities EnableMongo `
            --default-consistency-level Session `
            --locations regionName=$Location failoverPriority=0 isZoneRedundant=False
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "فشل في إنشاء حساب Cosmos DB." -ForegroundColor Red
            return $false
        }
    }
    
    # إنشاء قاعدة بيانات MongoDB
    Write-Host "إنشاء قاعدة بيانات MongoDB '$DBName'..." -ForegroundColor Yellow
    az cosmosdb mongodb database create `
        --account-name $AccountName `
        --resource-group $ResourceGroup `
        --name $DBName
    
    # إنشاء مجموعة MongoDB
    Write-Host "إنشاء مجموعة MongoDB '$CollectionName'..." -ForegroundColor Yellow
    az cosmosdb mongodb collection create `
        --account-name $AccountName `
        --resource-group $ResourceGroup `
        --database-name $DBName `
        --name $CollectionName `
        --shard "model" `
        --throughput 400
    
    # الحصول على مفاتيح الاتصال
    $keys = az cosmosdb keys list --name $AccountName --resource-group $ResourceGroup | ConvertFrom-Json
    $primaryKey = $keys.primaryMasterKey
    
    # الحصول على نقطة نهاية الاتصال
    $endpoint = az cosmosdb show --name $AccountName --resource-group $ResourceGroup --query documentEndpoint --output tsv
    
    # بناء سلسلة اتصال MongoDB
    $connectionString = "mongodb://$AccountName:$primaryKey@$AccountName.mongo.cosmos.azure.com:10255/$DBName?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@$AccountName@"
    
    return @{
        AccountName = $AccountName
        DatabaseName = $DBName
        CollectionName = $CollectionName
        ConnectionString = $connectionString
        PrimaryKey = $primaryKey
        Endpoint = $endpoint
    }
}

# إنشاء ملف .env للتطبيق
function New-EnvFile {
    param (
        [hashtable]$PostgresInfo,
        [hashtable]$CosmosInfo
    )
    
    $envContent = @"
# متغيرات قاعدة بيانات PostgreSQL
DB_HOST=$($PostgresInfo.FQDN)
DB_PORT=5432
DB_USER=$($PostgresInfo.AdminUser)
DB_PASSWORD=$($PostgresInfo.AdminPassword)
DB_NAME=$($PostgresInfo.DatabaseName)
DATABASE_URL=$($PostgresInfo.ConnectionString)

# متغيرات قاعدة بيانات MongoDB
MONGO_URI=$($CosmosInfo.ConnectionString)
MONGODB_URI=$($CosmosInfo.ConnectionString)

# متغيرات بيئة التطبيق
NODE_ENV=production
PORT=3001
JWT_SECRET=your_jwt_secret_here
ENABLE_AI_FEATURES=true
ENABLE_FALLBACK=true
MAX_DAILY_TOKENS=100000
MAX_MONTHLY_TOKENS=3000000
"@
    
    $envPath = Join-Path -Path (Get-Location) -ChildPath ".env.azure"
    $envContent | Out-File -FilePath $envPath -Encoding utf8
    
    Write-Host "تم إنشاء ملف .env.azure في المسار: $envPath" -ForegroundColor Green
}

# الدالة الرئيسية
function Main {
    # التحقق من تسجيل الدخول إلى Azure
    Test-AzureLogin
    
    # التحقق من وجود مجموعة الموارد
    Test-ResourceGroup -ResourceGroup $ResourceGroup
    
    # إنشاء خادم PostgreSQL
    Write-Host "`n===== إنشاء قاعدة بيانات PostgreSQL =====" -ForegroundColor Cyan
    $postgresInfo = New-PostgreSQLServer `
        -ResourceGroup $ResourceGroup `
        -ServerName $PostgresServerName `
        -Location $Location `
        -AdminUser $PostgresAdminUser `
        -AdminPassword $PostgresAdminPassword `
        -DBName $PostgresDBName `
        -CreateFirewallRules $CreateFirewallRules `
        -EnablePublicAccess $EnablePublicAccess
    
    # إنشاء حساب Cosmos DB
    Write-Host "`n===== إنشاء قاعدة بيانات Cosmos DB (MongoDB) =====" -ForegroundColor Cyan
    $cosmosInfo = New-CosmosDBAccount `
        -ResourceGroup $ResourceGroup `
        -AccountName $CosmosAccountName `
        -Location $Location `
        -DBName $CosmosDBName `
        -CollectionName $CosmosCollectionName
    
    # إنشاء ملف .env
    New-EnvFile -PostgresInfo $postgresInfo -CosmosInfo $cosmosInfo
    
    # عرض معلومات الاتصال
    Write-Host "`n===== معلومات الاتصال بقواعد البيانات =====" -ForegroundColor Cyan
    Write-Host "PostgreSQL Connection String: $($postgresInfo.ConnectionString)" -ForegroundColor Yellow
    Write-Host "MongoDB Connection String: $($cosmosInfo.ConnectionString)" -ForegroundColor Yellow
    
    Write-Host "`n✅ تم إنشاء قواعد البيانات بنجاح!" -ForegroundColor Green
    Write-Host "يمكنك استخدام ملف .env.azure لتكوين تطبيقك للاتصال بقواعد البيانات." -ForegroundColor Green
}

# تنفيذ الدالة الرئيسية
Main
