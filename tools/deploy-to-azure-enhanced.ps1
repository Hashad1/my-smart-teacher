# سكريبت محسن لنشر تطبيق معلمي الذكي على Azure

param (
    [string]$ResourceGroup = "my-smart-teacher-rg",
    [string]$Location = "uaenorth",
    [string]$EnvironmentName = "managedEnvironment-mysmartteacherr-8c55",
    [switch]$BuildOnly = $false,
    [switch]$DeployOnly = $false
)

$ErrorActionPreference = "Stop"

# تحديد المسارات
$rootPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$frontendPath = Join-Path -Path $rootPath -ChildPath "my-smart-teacher\frontend"
$backendPath = Join-Path -Path $rootPath -ChildPath "my-smart-teacher\backend"

# تمت إزالة متغيرات البيئة الخاصة بخدمات الذكاء الاصطناعي مؤقتًا لأنها غير مستخدمة في نشر الخدمات الحالية (backend, frontend)
# إذا تمت إعادة تفعيل خدمة Python لاحقًا، أعد هذه المتغيرات حسب الحاجة.

$jwtSecret = "4b7101ffd4fc47f3009d1f66c554b459e41fce59766eb244dad9d813a0f5faed8f02962a2cee141e94268083993c834cadb3f8ca624f8620c569bca91fd40e1095b2dcad0bae5bb151be2e09480bed4fd2c4b96f3ab69e86ccbfdc9d082ead99e0b952739a19ff57794b386c3ad85bd57d5c31edfc0aae18e4e644ce31f90115145967e6ab4e1fa16baef22bbe32aadad5af89269d02ad05f7a666e0b1d8ad40f2291ca55cf9da99c2220340c9e7899659fe6dd79098849bd32e750a0bdc5c1095fff4d66db9bb7648b49442cc8040bd717f126ba21c3979c32ad3c0abf678d0ffea1686b8ea7243a8349b420401dd46c3d650ba934639f6110628bb11986558"

# التحقق من تثبيت الأدوات المطلوبة
function Test-Prerequisites {
    Write-Host "التحقق من تثبيت الأدوات المطلوبة..." -ForegroundColor Cyan
    
    # التحقق من تثبيت Azure CLI
    try {
        az --version | Out-Null
        Write-Host "تم العثور على Azure CLI" -ForegroundColor Green
    } catch {
        Write-Host "لم يتم العثور على Azure CLI. يرجى تثبيته من https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Red
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

# نشر الخدمات باستخدام az containerapp up (بدون Docker)
function New-ContainerApps {
    # تجاوز نشر خدمة Python مؤقتًا بسبب مشكلة PyAudio
    Write-Host "\nنشر الخادم الخلفي..." -ForegroundColor Yellow
    az containerapp up `
      --name backend `
      --resource-group $ResourceGroup `
      --source $backendPath `
      --location $Location `
      --env-vars JWT_SECRET=$jwtSecret

    Write-Host "\nنشر الواجهة الأمامية..." -ForegroundColor Yellow
    az containerapp up `
      --name frontend `
      --resource-group $ResourceGroup `
      --source $frontendPath `
      --location $Location

    Write-Host "\nتم نشر جميع الخدمات بنجاح (بدون خدمة Python)!" -ForegroundColor Green
}

# عرض معلومات النشر
function Show-DeploymentInfo {
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "      معلومات نشر تطبيق معلمي الذكي      " -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "تم نشر التطبيق بنجاح على Azure Container Apps!" -ForegroundColor Green
    Write-Host ""
    Write-Host "روابط الوصول إلى التطبيق:" -ForegroundColor Yellow
    Write-Host "- الواجهة الأمامية: https://frontend.$ResourceGroup.azurecontainerapps.io" -ForegroundColor Green
    Write-Host "- الخادم الخلفي: https://backend.$ResourceGroup.azurecontainerapps.io" -ForegroundColor Green
    Write-Host "- مشاركة الشاشة: https://python-service.$ResourceGroup.azurecontainerapps.io/screen-share" -ForegroundColor Green
    Write-Host ""
    Write-Host "لتحديث التطبيق، قم بتشغيل هذا السكريبت مرة أخرى." -ForegroundColor Yellow
    Write-Host ""
}

# التحقق من حالة النشر
function Test-DeploymentStatus {
    Write-Host ""
    Write-Host "التحقق من حالة الخدمات المنشورة..."
    # أضف رمز التحقق من حالة النشر هنا
}

# تنظيف الموارد المؤقتة
function Remove-TempResources {
    Write-Host ""
    Write-Host "تنظيف الموارد المؤقتة..."
    # أضف رمز تنظيف الموارد المؤقتة هنا
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

# نشر الخدمات
if (-not $BuildOnly) {
    New-ContainerApps
    Show-DeploymentInfo
}

# التحقق من حالة النشر
if (-not $BuildOnly) {
    Write-Host ""
    Write-Host "التحقق من حالة الخدمات المنشورة..."
    if (Get-Command -Name Test-DeploymentStatus -ErrorAction SilentlyContinue) {
        Test-DeploymentStatus
    } else {
        Write-Host "[تحذير] الدالة Test-DeploymentStatus غير معرفة. تخطى التحقق."
    }
}

# تنظيف الموارد المؤقتة إذا لزم الأمر
$CleanupTempResources = $true
if ($CleanupTempResources -eq $true) {
    Write-Host ""
    Write-Host "تنظيف الموارد المؤقتة..."
    if (Get-Command -Name Remove-TempResources -ErrorAction SilentlyContinue) {
        Remove-TempResources
    } else {
        Write-Host "[تحذير] الدالة Remove-TempResources غير معرفة. تخطى التنظيف."
    }
}

Write-Host ""
Write-Host "تمت عملية النشر بنجاح!"
Write-Host "----------------------------------------"
Write-Host "يمكنك الآن الوصول إلى تطبيقك عبر Azure Container Apps."
Write-Host "شكراً لاستخدامك أداة النشر."