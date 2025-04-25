# سكريبت محسن لنشر تطبيق معلمي الذكي على Azure

param (
    [string]$ResourceGroup = "my-smart-teacher-rg",
    [string]$Location = "westeurope",
    [string]$RegistryName = "mysmartteacheracr",
    [switch]$BuildOnly = $false,
    [switch]$DeployOnly = $false
)

$ErrorActionPreference = "Stop"

# تحديد المسارات
$rootPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$pythonServicePath = Join-Path -Path $rootPath -ChildPath "python_service_enhanced"
$frontendPath = Join-Path -Path $rootPath -ChildPath "my-smart-teacher\frontend"
$backendPath = Join-Path -Path $rootPath -ChildPath "my-smart-teacher\backend"

# التحقق من تثبيت الأدوات المطلوبة
function Test-Prerequisites {
    Write-Host "التحقق من تثبيت الأدوات المطلوبة..." -ForegroundColor Cyan
    
    # التحقق من تثبيت Azure CLI
    try {
        az --version | Out-Null
        Write-Host "تم العثور على Azure CLI" -ForegroundColor Green
    } 
    catch {
        Write-Host "لم يتم العثور على Azure CLI. يرجى تثبيته من https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Red
        exit 1
    }
    
    # التحقق من تثبيت Docker
    try {
        docker --version | Out-Null
        Write-Host "تم العثور على Docker" -ForegroundColor Green
    } 
    catch {
        Write-Host "لم يتم العثور على Docker. يرجى تثبيته من https://docs.docker.com/get-docker/" -ForegroundColor Red
        exit 1
    }
}

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

# إنشاء الموارد في Azure
function New-AzureResources {
    Write-Host "إنشاء الموارد في Azure..." -ForegroundColor Cyan
    
    # إنشاء مجموعة الموارد
    Write-Host "إنشاء مجموعة الموارد $ResourceGroup..." -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location
    
    # إنشاء سجل الحاويات
    Write-Host "إنشاء سجل الحاويات $RegistryName..." -ForegroundColor Yellow
    az acr create --resource-group $ResourceGroup --name $RegistryName --sku Basic --admin-enabled true
    
    # الحصول على بيانات اعتماد سجل الحاويات
    $credentials = az acr credential show --name $RegistryName | ConvertFrom-Json
    $username = $credentials.username
    $password = ConvertTo-SecureString $credentials.passwords[0].value -AsPlainText -Force
    
    Write-Host "تم إنشاء الموارد في Azure بنجاح" -ForegroundColor Green
    
    return @{
        Username = $username
        Password = $password
    }
}

# بناء ودفع الصور
function Build-And-Push-Images {
    param (
        [string]$Username,
        [System.Security.SecureString]$Password
    )
    
    Write-Host "بناء ودفع الصور..." -ForegroundColor Cyan
    
    # تسجيل الدخول إلى سجل الحاويات
    Write-Host "تسجيل الدخول إلى سجل الحاويات $RegistryName..." -ForegroundColor Yellow
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    
    Write-Output $PlainPassword | docker login "$RegistryName.azurecr.io" --username $Username --password-stdin
    
    # بناء الصور
    Write-Host "بناء صورة الواجهة الأمامية..." -ForegroundColor Yellow
    docker build -t "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest" $frontendPath
    
    Write-Host "بناء صورة الخادم الخلفي..." -ForegroundColor Yellow
    docker build -t "$RegistryName.azurecr.io/my-smart-teacher-backend:latest" $backendPath
    
    Write-Host "بناء صورة خدمة Python المحسنة..." -ForegroundColor Yellow
    docker build -t "$RegistryName.azurecr.io/my-smart-teacher-python:latest" $pythonServicePath
    
    # دفع الصور
    Write-Host "دفع الصور إلى سجل الحاويات..." -ForegroundColor Yellow
    docker push "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest"
    docker push "$RegistryName.azurecr.io/my-smart-teacher-backend:latest"
    docker push "$RegistryName.azurecr.io/my-smart-teacher-python:latest"
    
    Write-Host "تم بناء ودفع الصور بنجاح" -ForegroundColor Green
}

# إنشاء تطبيقات الحاويات
function New-ContainerApps {
    Write-Host "إنشاء تطبيقات الحاويات..." -ForegroundColor Cyan
    
    # إنشاء بيئة تطبيقات الحاويات
    Write-Host "إنشاء بيئة تطبيقات الحاويات..." -ForegroundColor Yellow
    az containerapp env create `
        --name "my-smart-teacher-env" `
        --resource-group $ResourceGroup `
        --location $Location
    
    # إنشاء تطبيق خدمة Python
    Write-Host "إنشاء تطبيق خدمة Python..." -ForegroundColor Yellow
    az containerapp create `
        --name "python-service" `
        --resource-group $ResourceGroup `
        --environment "my-smart-teacher-env" `
        --image "$RegistryName.azurecr.io/my-smart-teacher-python:latest" `
        --registry-server "$RegistryName.azurecr.io" `
        --registry-username $RegistryName `
        --registry-password $(az acr credential show --name $RegistryName --query "passwords[0].value" -o tsv) `
        --target-port 8085 `
        --ingress "external" `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    # الحصول على عنوان URL لخدمة Python
    $pythonServiceUrl = az containerapp show `
        --name "python-service" `
        --resource-group $ResourceGroup `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    # إنشاء تطبيق الخادم الخلفي
    Write-Host "إنشاء تطبيق الخادم الخلفي..." -ForegroundColor Yellow
    az containerapp create `
        --name "backend" `
        --resource-group $ResourceGroup `
        --environment "my-smart-teacher-env" `
        --image "$RegistryName.azurecr.io/my-smart-teacher-backend:latest" `
        --registry-server "$RegistryName.azurecr.io" `
        --registry-username $RegistryName `
        --registry-password $(az acr credential show --name $RegistryName --query "passwords[0].value" -o tsv) `
        --target-port 3001 `
        --ingress "external" `
        --env-vars "PYTHON_SERVICE_URL=https://$pythonServiceUrl" `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    # الحصول على عنوان URL للخادم الخلفي
    $backendUrl = az containerapp show `
        --name "backend" `
        --resource-group $ResourceGroup `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    # إنشاء تطبيق الواجهة الأمامية
    Write-Host "إنشاء تطبيق الواجهة الأمامية..." -ForegroundColor Yellow
    az containerapp create `
        --name "frontend" `
        --resource-group $ResourceGroup `
        --environment "my-smart-teacher-env" `
        --image "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest" `
        --registry-server "$RegistryName.azurecr.io" `
        --registry-username $RegistryName `
        --registry-password $(az acr credential show --name $RegistryName --query "passwords[0].value" -o tsv) `
        --target-port 3000 `
        --ingress "external" `
        --env-vars "VITE_API_URL=https://$backendUrl" "VITE_PYTHON_SERVICE_URL=https://$pythonServiceUrl" `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    # الحصول على عنوان URL للواجهة الأمامية
    $frontendUrl = az containerapp show `
        --name "frontend" `
        --resource-group $ResourceGroup `
        --query "properties.configuration.ingress.fqdn" -o tsv
    
    Write-Host "تم إنشاء تطبيقات الحاويات بنجاح" -ForegroundColor Green
    
    return @{
        FrontendUrl = "https://$frontendUrl"
        BackendUrl = "https://$backendUrl"
        PythonServiceUrl = "https://$pythonServiceUrl"
    }
}

# عرض معلومات النشر
function Show-DeploymentInfo {
    param (
        [string]$FrontendUrl,
        [string]$BackendUrl,
        [string]$PythonServiceUrl
    )
    
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "      معلومات نشر تطبيق معلمي الذكي      " -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "تم نشر التطبيق بنجاح على Azure Container Apps!" -ForegroundColor Green
    Write-Host ""
    Write-Host "روابط الوصول إلى التطبيق:" -ForegroundColor Yellow
    Write-Host "- الواجهة الأمامية: $FrontendUrl" -ForegroundColor Green
    Write-Host "- الخادم الخلفي: $BackendUrl" -ForegroundColor Green
    Write-Host "- خدمة Python: $PythonServiceUrl" -ForegroundColor Green
    Write-Host "- مشاركة الشاشة: $PythonServiceUrl/screen-share" -ForegroundColor Green
    Write-Host ""
    Write-Host "لتحديث التطبيق، قم بتشغيل هذا السكريبت مرة أخرى." -ForegroundColor Yellow
    Write-Host ""
}

# التنفيذ الرئيسي
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      نشر تطبيق معلمي الذكي على Azure      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# التحقق من المتطلبات الأساسية
Test-Prerequisites

# تسجيل الدخول إلى Azure
if (-not $BuildOnly) {
    Connect-ToAzure
}

# إنشاء الموارد في Azure
if (-not $BuildOnly -and -not $DeployOnly) {
    $credentials = New-AzureResources
    $username = $credentials.Username
    $password = $credentials.Password
} else {
    # الحصول على بيانات اعتماد سجل الحاويات
    $credentials = az acr credential show --name $RegistryName | ConvertFrom-Json
    $username = $credentials.username
    $password = ConvertTo-SecureString $credentials.passwords[0].value -AsPlainText -Force
}

# بناء ودفع الصور
if (-not $DeployOnly) {
    Build-And-Push-Images -Username $username -Password $password
}

# إنشاء تطبيقات الحاويات
if (-not $BuildOnly) {
    $urls = New-ContainerApps
    Show-DeploymentInfo -FrontendUrl $urls.FrontendUrl -BackendUrl $urls.BackendUrl -PythonServiceUrl $urls.PythonServiceUrl
}

Write-Host "تم الانتهاء من عملية النشر!" -ForegroundColor Cyan
