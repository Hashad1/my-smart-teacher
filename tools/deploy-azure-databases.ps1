#!/usr/bin/env pwsh
# سكريبت نشر قواعد البيانات على Azure باستخدام ملف Bicep

param (
    [string]$ResourceGroup = "my-smart-teacher-rg",
    [string]$Location = "uaenorth",
    [string]$BicepFile = "azure-databases.bicep",
    [string]$PostgresServerName = "my-smart-teacher-postgres",
    [string]$PostgresAdminUser = "mstadmin",
    [string]$PostgresAdminPassword = "",
    [string]$PostgresDBName = "my_smart_teacher",
    [string]$CosmosAccountName = "my-smart-teacher-cosmos",
    [string]$CosmosDBName = "my_smart_teacher",
    [string]$CosmosCollectionName = "model_usage_stats",
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

# نشر ملف Bicep
function Deploy-BicepTemplate {
    param (
        [string]$ResourceGroup,
        [string]$BicepFile,
        [hashtable]$Parameters
    )
    
    Write-Host "نشر قواعد البيانات باستخدام ملف Bicep..." -ForegroundColor Yellow
    
    # تحويل المعلمات إلى سلسلة
    $paramString = ""
    foreach ($key in $Parameters.Keys) {
        $paramString += " $key=$($Parameters[$key])"
    }
    
    # تنفيذ أمر النشر
    $deploymentName = "db-deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $output = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroup `
        --template-file $BicepFile `
        --parameters $paramString `
        --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "فشل في نشر قواعد البيانات." -ForegroundColor Red
        return $null
    }
    
    return $output.properties.outputs
}

# إنشاء ملف .env للتطبيق
function New-EnvFile {
    param (
        [PSCustomObject]$DeploymentOutputs
    )
    
    $postgresConnectionString = $DeploymentOutputs.postgresConnectionString.value
    $cosmosConnectionString = $DeploymentOutputs.cosmosConnectionString.value
    
    $envContent = @"
# متغيرات قاعدة بيانات PostgreSQL
DB_HOST=$($DeploymentOutputs.postgresServerFQDN.value)
DB_PORT=5432
DB_USER=$PostgresAdminUser
DB_PASSWORD=$PostgresAdminPassword
DB_NAME=$PostgresDBName
DATABASE_URL=$postgresConnectionString

# متغيرات قاعدة بيانات MongoDB
MONGO_URI=$cosmosConnectionString
MONGODB_URI=$cosmosConnectionString

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
    
    # التحقق من كلمة المرور
    if ([string]::IsNullOrEmpty($PostgresAdminPassword)) {
        $securePassword = Read-Host "أدخل كلمة مرور مشرف PostgreSQL" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $PostgresAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    
    # تحضير معلمات النشر
    $parameters = @{
        "resourceGroupName" = $ResourceGroup
        "location" = $Location
        "postgresServerName" = $PostgresServerName
        "postgresAdminUser" = $PostgresAdminUser
        "postgresAdminPassword" = $PostgresAdminPassword
        "postgresDBName" = $PostgresDBName
        "cosmosAccountName" = $CosmosAccountName
        "cosmosDBName" = $CosmosDBName
        "cosmosCollectionName" = $CosmosCollectionName
        "enablePublicAccess" = $EnablePublicAccess.ToString().ToLower()
    }
    
    # نشر قواعد البيانات
    Write-Host "`n===== نشر قواعد البيانات على Azure =====" -ForegroundColor Cyan
    $outputs = Deploy-BicepTemplate -ResourceGroup $ResourceGroup -BicepFile $BicepFile -Parameters $parameters
    
    if ($null -ne $outputs) {
        # إنشاء ملف .env
        New-EnvFile -DeploymentOutputs $outputs
        
        # عرض معلومات الاتصال
        Write-Host "`n===== معلومات الاتصال بقواعد البيانات =====" -ForegroundColor Cyan
        Write-Host "PostgreSQL Connection String: $($outputs.postgresConnectionString.value)" -ForegroundColor Yellow
        Write-Host "MongoDB Connection String: $($outputs.cosmosConnectionString.value)" -ForegroundColor Yellow
        
        Write-Host "`n✅ تم إنشاء قواعد البيانات بنجاح!" -ForegroundColor Green
        Write-Host "يمكنك استخدام ملف .env.azure لتكوين تطبيقك للاتصال بقواعد البيانات." -ForegroundColor Green
        
        # إرشادات إضافية
        Write-Host "`n===== الخطوات التالية =====" -ForegroundColor Cyan
        Write-Host "1. انسخ ملف .env.azure إلى دليل التطبيق الخلفي" -ForegroundColor White
        Write-Host "2. قم بتحديث متغيرات البيئة في تطبيق Container App الخاص بك" -ForegroundColor White
        Write-Host "3. قم بتشغيل الترحيلات لإنشاء الجداول في قاعدة البيانات PostgreSQL" -ForegroundColor White
    }
}

# تنفيذ الدالة الرئيسية
Main
