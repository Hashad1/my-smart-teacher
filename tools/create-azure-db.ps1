#!/usr/bin/env pwsh
# سكريبت بسيط لإنشاء قواعد البيانات على Azure

# المعلمات
$ResourceGroup = "my-smart-teacher-rg"
$Location = "uaenorth"
$PostgresServerName = "my-smart-teacher-pg"
$PostgresAdminUser = "mstadmin"
$PostgresDBName = "my_smart_teacher"
$CosmosAccountName = "my-smart-teacher-cosmos"
$CosmosDBName = "my_smart_teacher"
$CosmosCollectionName = "model_usage_stats"
$EnablePublicAccess = $false

# طلب كلمة المرور
$PostgresAdminPassword = Read-Host "أدخل كلمة مرور مشرف PostgreSQL" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PostgresAdminPassword)
$PostgresPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# التحقق من تسجيل الدخول إلى Azure
Write-Host "التحقق من تسجيل الدخول إلى Azure..." -ForegroundColor Cyan
try {
    $account = az account show | ConvertFrom-Json
    Write-Host "تم تسجيل الدخول كـ: $($account.user.name)" -ForegroundColor Green
}
catch {
    Write-Host "لم يتم تسجيل الدخول إلى Azure. الرجاء تسجيل الدخول أولاً." -ForegroundColor Red
    az login
}

# التحقق من وجود مجموعة الموارد
Write-Host "التحقق من وجود مجموعة الموارد..." -ForegroundColor Cyan
$exists = az group exists --name $ResourceGroup
if ($exists -eq "true") {
    Write-Host "مجموعة الموارد '$ResourceGroup' موجودة بالفعل." -ForegroundColor Green
}
else {
    Write-Host "إنشاء مجموعة الموارد '$ResourceGroup' في الموقع '$Location'..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location
}

# إنشاء خادم PostgreSQL
Write-Host "`n===== إنشاء قاعدة بيانات PostgreSQL =====" -ForegroundColor Cyan
$serverExists = az postgres flexible-server show --name $PostgresServerName --resource-group $ResourceGroup 2>$null
if ($serverExists) {
    Write-Host "خادم PostgreSQL '$PostgresServerName' موجود بالفعل." -ForegroundColor Green
}
else {
    Write-Host "إنشاء خادم PostgreSQL '$PostgresServerName'..." -ForegroundColor Yellow
    
    # إنشاء خادم PostgreSQL المرن
    az postgres flexible-server create `
        --name $PostgresServerName `
        --resource-group $ResourceGroup `
        --location $Location `
        --admin-user $PostgresAdminUser `
        --admin-password $PostgresPasswordText `
        --sku-name Standard_B1ms `
        --tier Burstable `
        --storage-size 32 `
        --version 14 `
        --high-availability Disabled `
        --public-access $EnablePublicAccess
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "فشل في إنشاء خادم PostgreSQL." -ForegroundColor Red
        exit 1
    }
}

# إنشاء قاعدة البيانات PostgreSQL
Write-Host "إنشاء قاعدة بيانات PostgreSQL '$PostgresDBName'..." -ForegroundColor Yellow
az postgres flexible-server db create `
    --resource-group $ResourceGroup `
    --server-name $PostgresServerName `
    --database-name $PostgresDBName

# إضافة قواعد جدار الحماية إذا تم تمكين الوصول العام
if ($EnablePublicAccess) {
    Write-Host "إضافة قاعدة جدار الحماية للسماح بالوصول من خدمات Azure..." -ForegroundColor Yellow
    az postgres flexible-server firewall-rule create `
        --resource-group $ResourceGroup `
        --name $PostgresServerName `
        --rule-name AllowAzureServices `
        --start-ip-address 0.0.0.0 `
        --end-ip-address 0.0.0.0
}

# إنشاء حساب Cosmos DB
Write-Host "`n===== إنشاء قاعدة بيانات Cosmos DB (MongoDB) =====" -ForegroundColor Cyan
$accountExists = az cosmosdb check-name-exists --name $CosmosAccountName
if ($accountExists -eq "true") {
    Write-Host "حساب Cosmos DB '$CosmosAccountName' موجود بالفعل." -ForegroundColor Green
}
else {
    Write-Host "إنشاء حساب Cosmos DB '$CosmosAccountName' مع واجهة MongoDB API..." -ForegroundColor Yellow
    
    # إنشاء حساب Cosmos DB مع واجهة MongoDB
    az cosmosdb create `
        --name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --kind MongoDB `
        --capabilities EnableMongo `
        --default-consistency-level Session `
        --locations regionName=$Location failoverPriority=0 isZoneRedundant=False
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "فشل في إنشاء حساب Cosmos DB." -ForegroundColor Red
        exit 1
    }
}

# إنشاء قاعدة بيانات MongoDB
Write-Host "إنشاء قاعدة بيانات MongoDB '$CosmosDBName'..." -ForegroundColor Yellow
az cosmosdb mongodb database create `
    --account-name $CosmosAccountName `
    --resource-group $ResourceGroup `
    --name $CosmosDBName

# إنشاء مجموعة MongoDB
Write-Host "إنشاء مجموعة MongoDB '$CosmosCollectionName'..." -ForegroundColor Yellow
az cosmosdb mongodb collection create `
    --account-name $CosmosAccountName `
    --resource-group $ResourceGroup `
    --database-name $CosmosDBName `
    --name $CosmosCollectionName `
    --shard "model" `
    --throughput 400

# الحصول على معلومات الاتصال
Write-Host "`n===== الحصول على معلومات الاتصال =====" -ForegroundColor Cyan

# معلومات PostgreSQL
$PostgresFQDN = "$PostgresServerName.postgres.database.azure.com"
$PostgresConnectionString = "postgres://$PostgresAdminUser:$PostgresPasswordText@$PostgresFQDN:5432/$PostgresDBName"

# معلومات Cosmos DB
$CosmosKeys = az cosmosdb keys list --name $CosmosAccountName --resource-group $ResourceGroup | ConvertFrom-Json
$CosmosPrimaryKey = $CosmosKeys.primaryMasterKey
$CosmosConnectionString = "mongodb://$CosmosAccountName`:$CosmosPrimaryKey@$CosmosAccountName.mongo.cosmos.azure.com:10255/$CosmosDBName?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@$CosmosAccountName@"

# إنشاء ملف .env
$envContent = @"
# متغيرات قاعدة بيانات PostgreSQL
DB_HOST=$PostgresFQDN
DB_PORT=5432
DB_USER=$PostgresAdminUser
DB_PASSWORD=$PostgresPasswordText
DB_NAME=$PostgresDBName
DATABASE_URL=$PostgresConnectionString

# متغيرات قاعدة بيانات MongoDB
MONGO_URI=$CosmosConnectionString
MONGODB_URI=$CosmosConnectionString

# متغيرات بيئة التطبيق
NODE_ENV=production
PORT=3001
JWT_SECRET=your_jwt_secret_here
ENABLE_AI_FEATURES=true
ENABLE_FALLBACK=true
MAX_DAILY_TOKENS=100000
MAX_MONTHLY_TOKENS=3000000

# متغيرات مفاتيح API للذكاء الاصطناعي
OPENAI_API_KEY=your_openai_api_key_here
GOOGLE_AI_API_KEY=your_google_ai_api_key_here
GROQ_API_KEY=your_groq_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# متغيرات الأمان
CRYPTO_SECRET_KEY=your_crypto_secret_key_here
CRYPTO_IV=your_crypto_iv_here
"@

$envPath = Join-Path -Path (Get-Location) -ChildPath ".env.azure"
$envContent | Out-File -FilePath $envPath -Encoding utf8

Write-Host "تم إنشاء ملف .env.azure في المسار: $envPath" -ForegroundColor Green

# عرض معلومات الاتصال
Write-Host "`n===== معلومات الاتصال بقواعد البيانات =====" -ForegroundColor Cyan
Write-Host "PostgreSQL Connection String: $PostgresConnectionString" -ForegroundColor Yellow
Write-Host "MongoDB Connection String: $CosmosConnectionString" -ForegroundColor Yellow

Write-Host "`n✅ تم إنشاء قواعد البيانات بنجاح!" -ForegroundColor Green
Write-Host "يمكنك استخدام ملف .env.azure لتكوين تطبيقك للاتصال بقواعد البيانات." -ForegroundColor Green

# إرشادات إضافية
Write-Host "`n===== الخطوات التالية =====" -ForegroundColor Cyan
Write-Host "1. انسخ ملف .env.azure إلى دليل التطبيق الخلفي" -ForegroundColor White
Write-Host "2. قم بتحديث متغيرات البيئة في تطبيق Container App الخاص بك" -ForegroundColor White
Write-Host "3. قم بتشغيل الترحيلات لإنشاء الجداول في قاعدة البيانات PostgreSQL" -ForegroundColor White

# إظهار معلومات عن المستودعات والخدمات
Write-Host "`n===== المستودعات والخدمات المدعومة =====" -ForegroundColor Cyan
Write-Host "المستودعات:" -ForegroundColor White
Write-Host "- ModelFallbackLogRepository: يتعامل مع سجلات تبديل النماذج" -ForegroundColor White
Write-Host "- AiModelConfigRepository: يدير إعدادات نماذج الذكاء الاصطناعي" -ForegroundColor White
Write-Host "- PromptTemplateRepository: يدير قوالب البرومبت" -ForegroundColor White
Write-Host "- PromptLibraryImportRepository: يتعامل مع سجلات استيراد مكتبة البرومبت" -ForegroundColor White
Write-Host "- ModelUsageStatsRepository: يدير إحصائيات استخدام النماذج في MongoDB" -ForegroundColor White
Write-Host "- AiTeacherRepository: يدير المعلمين الذكيين" -ForegroundColor White

Write-Host "`nالخدمات:" -ForegroundColor White
Write-Host "- ApiKeyService: خدمة شاملة لإدارة مفاتيح API" -ForegroundColor White
Write-Host "- CryptoService: خدمة للتشفير وفك التشفير" -ForegroundColor White
Write-Host "- SystemSettingService: خدمة لإدارة إعدادات النظام" -ForegroundColor White
Write-Host "- AiModelConfigService: خدمة لإدارة إعدادات نماذج الذكاء الاصطناعي" -ForegroundColor White
Write-Host "- PromptTemplateService: خدمة لإدارة قوالب البرومبت" -ForegroundColor White
Write-Host "- ModelUsageStatsService: خدمة لإدارة وتحليل إحصائيات استخدام النماذج" -ForegroundColor White
