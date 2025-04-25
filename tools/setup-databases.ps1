# سكريبت إعداد قواعد البيانات لتطبيق معلمي الذكي على Azure

param (
    [string]$ResourceGroup = "my-smart-teacher-rg",
    [string]$Location = "uaenorth",
    [string]$SqlServerName = "mysmartteacher-sql",
    [string]$SqlDatabaseName = "mysmartteacher-db",
    [string]$CosmosAccountName = "mysmartteacher-cosmos",
    [string]$CosmosDatabaseName = "mysmartteacher-nosql",
    [string]$AdminUsername = "mysmartteacheradmin",
    [string]$AdminPassword = "P@ssw0rd123!@#",
    [switch]$SkipSqlDatabase = $false,
    [switch]$SkipCosmosDB = $false
)

$ErrorActionPreference = "Stop"

# تسجيل الدخول إلى Azure
function Connect-ToAzure {
    Write-Host "تسجيل الدخول إلى Azure..." -ForegroundColor Cyan
    az login
    
    # التحقق من نجاح تسجيل الدخول
    if ($LASTEXITCODE -ne 0) {
        Write-Host "فشل تسجيل الدخول إلى Azure" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "تم تسجيل الدخول إلى Azure بنجاح" -ForegroundColor Green
}

# إنشاء خادم SQL
function New-SqlServer {
    Write-Host "إنشاء خادم SQL $SqlServerName..." -ForegroundColor Cyan
    
    # إنشاء خادم SQL
    az sql server create `
        --name $SqlServerName `
        --resource-group $ResourceGroup `
        --location $Location `
        --admin-user $AdminUsername `
        --admin-password $AdminPassword
    
    # تكوين قواعد جدار الحماية للسماح بالوصول من خدمات Azure
    Write-Host "تكوين قواعد جدار الحماية للسماح بالوصول من خدمات Azure..." -ForegroundColor Yellow
    az sql server firewall-rule create `
        --resource-group $ResourceGroup `
        --server $SqlServerName `
        --name "AllowAzureServices" `
        --start-ip-address 0.0.0.0 `
        --end-ip-address 0.0.0.0
    
    Write-Host "تم إنشاء خادم SQL بنجاح" -ForegroundColor Green
}

# إنشاء قاعدة بيانات SQL
function New-SqlDatabase {
    Write-Host "إنشاء قاعدة بيانات SQL $SqlDatabaseName..." -ForegroundColor Cyan
    
    # إنشاء قاعدة بيانات SQL
    az sql db create `
        --resource-group $ResourceGroup `
        --server $SqlServerName `
        --name $SqlDatabaseName `
        --service-objective Basic `
        --zone-redundant false
    
    Write-Host "تم إنشاء قاعدة بيانات SQL بنجاح" -ForegroundColor Green
    
    # الحصول على سلسلة الاتصال
    $connectionString = az sql db show-connection-string `
        --name $SqlDatabaseName `
        --server $SqlServerName `
        --client ado.net `
        --output tsv
    
    # استبدال الرموز في سلسلة الاتصال
    $connectionString = $connectionString.Replace("<username>", $AdminUsername).Replace("<password>", $AdminPassword)
    
    return $connectionString
}

# إنشاء حساب Cosmos DB
function New-CosmosAccount {
    Write-Host "إنشاء حساب Cosmos DB $CosmosAccountName..." -ForegroundColor Cyan
    
    # إنشاء حساب Cosmos DB
    az cosmosdb create `
        --name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --kind GlobalDocumentDB `
        --default-consistency-level Session `
        --locations regionName=$Location
    
    Write-Host "تم إنشاء حساب Cosmos DB بنجاح" -ForegroundColor Green
}

# إنشاء قاعدة بيانات Cosmos DB
function New-CosmosDatabase {
    Write-Host "إنشاء قاعدة بيانات Cosmos DB $CosmosDatabaseName..." -ForegroundColor Cyan
    
    # إنشاء قاعدة بيانات Cosmos DB
    az cosmosdb sql database create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --name $CosmosDatabaseName
    
    Write-Host "تم إنشاء قاعدة بيانات Cosmos DB بنجاح" -ForegroundColor Green
    
    # إنشاء حاويات للبيانات المختلفة
    Write-Host "إنشاء حاويات للبيانات المختلفة..." -ForegroundColor Yellow
    
    # حاوية للمستخدمين
    az cosmosdb sql container create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --database-name $CosmosDatabaseName `
        --name "users" `
        --partition-key-path "/userId"
    
    # حاوية للمحتوى التعليمي
    az cosmosdb sql container create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --database-name $CosmosDatabaseName `
        --name "educationalContent" `
        --partition-key-path "/contentId"
    
    # حاوية لتفاعلات المستخدمين
    az cosmosdb sql container create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --database-name $CosmosDatabaseName `
        --name "interactions" `
        --partition-key-path "/userId"
    
    # حاوية لتحليل الصور والنصوص
    az cosmosdb sql container create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --database-name $CosmosDatabaseName `
        --name "analysis" `
        --partition-key-path "/analysisId"
    
    # حاوية لسجلات مشاركة الشاشة
    az cosmosdb sql container create `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --database-name $CosmosDatabaseName `
        --name "screenSharing" `
        --partition-key-path "/sessionId"
    
    Write-Host "تم إنشاء الحاويات بنجاح" -ForegroundColor Green
    
    # الحصول على مفتاح Cosmos DB
    $cosmosKey = az cosmosdb keys list `
        --name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --query primaryMasterKey `
        --output tsv
    
    # الحصول على نقطة النهاية لـ Cosmos DB
    $cosmosEndpoint = az cosmosdb show `
        --name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --query documentEndpoint `
        --output tsv
    
    return @{
        Key = $cosmosKey
        Endpoint = $cosmosEndpoint
    }
}

# تحديث متغيرات البيئة في سكريبت النشر
function Update-DeploymentScript {
    param (
        [string]$SqlConnectionString,
        [string]$CosmosKey,
        [string]$CosmosEndpoint
    )
    
    Write-Host "تحديث سكريبت النشر بمعلومات قواعد البيانات..." -ForegroundColor Cyan
    
    # قراءة محتوى السكريبت
    $deployScriptPath = Join-Path -Path (Split-Path -Parent $PSCommandPath) -ChildPath "deploy-to-azure-enhanced.ps1"
    $content = Get-Content -Path $deployScriptPath -Raw
    
    # إضافة متغيرات قواعد البيانات
    $dbVariables = @"

# Database Connection Information
`$sqlConnectionString = "$SqlConnectionString"
`$cosmosKey = "$CosmosKey"
`$cosmosEndpoint = "$CosmosEndpoint"
"@
    
    # إضافة المتغيرات بعد متغيرات API
    $content = $content -replace "(`\$serpirApiKey = .+)`r`n", "`$1`r`n$dbVariables`r`n"
    
    # تحديث متغيرات البيئة للخادم الخلفي
    $content = $content -replace '(--env-vars .+?"ENABLE_AI_FEATURES=true" "ENABLE_FALLBACK=true" `\r\n\s+"OPENAI_API_KEY=\$openaiApiKey" "GOOGLE_GENERATIVE_AI_API_KEY=\$googleGenerativeAiApiKey")', '$1 "SQL_CONNECTION_STRING=$sqlConnectionString" "COSMOS_KEY=$cosmosKey" "COSMOS_ENDPOINT=$cosmosEndpoint"'
    
    # كتابة المحتوى المحدث إلى السكريبت
    Set-Content -Path $deployScriptPath -Value $content
    
    Write-Host "تم تحديث سكريبت النشر بنجاح" -ForegroundColor Green
}

# التنفيذ الرئيسي
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      إعداد قواعد البيانات لتطبيق معلمي الذكي      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# تسجيل الدخول إلى Azure
Connect-ToAzure

# متغيرات لتخزين معلومات الاتصال
$sqlConnectionString = ""
$cosmosInfo = @{}

# إنشاء قاعدة بيانات SQL
if (-not $SkipSqlDatabase) {
    New-SqlServer
    $sqlConnectionString = New-SqlDatabase
    Write-Host "سلسلة اتصال SQL: $sqlConnectionString" -ForegroundColor Green
}

# إنشاء قاعدة بيانات Cosmos DB
if (-not $SkipCosmosDB) {
    New-CosmosAccount
    $cosmosInfo = New-CosmosDatabase
    Write-Host "مفتاح Cosmos DB: $($cosmosInfo.Key)" -ForegroundColor Green
    Write-Host "نقطة نهاية Cosmos DB: $($cosmosInfo.Endpoint)" -ForegroundColor Green
}

# تحديث سكريبت النشر
Update-DeploymentScript -SqlConnectionString $sqlConnectionString -CosmosKey $cosmosInfo.Key -CosmosEndpoint $cosmosInfo.Endpoint

Write-Host ""
Write-Host "تم إعداد قواعد البيانات بنجاح!" -ForegroundColor Cyan
Write-Host "يمكنك الآن تنفيذ سكريبت النشر لنشر التطبيق مع تكامل قواعد البيانات." -ForegroundColor Yellow
Write-Host ""
