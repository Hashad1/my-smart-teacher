# سكريبت لبدء خدمات معلمي الذكي
# يقوم هذا السكريبت بتشغيل كل من خدمة Node.js وخدمة Python

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      بدء تشغيل خدمات معلمي الذكي       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# دالة للتحقق مما إذا كان المنفذ قيد الاستخدام
function Test-PortInUse {
    param(
        [int]$Port
    )
    
    $connections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -eq $Port }
    return ($null -ne $connections)
}

# التحقق مما إذا كانت المنافذ متاحة
$frontendPort = 3000
$backendPort = 3001
$pythonPort = 5000

if (Test-PortInUse -Port $frontendPort) {
    Write-Host "خطأ: المنفذ $frontendPort قيد الاستخدام بالفعل. لا يمكن بدء خدمة الواجهة الأمامية." -ForegroundColor Red
    Write-Host "يرجى إغلاق التطبيق الذي يستخدم هذا المنفذ والمحاولة مرة أخرى." -ForegroundColor Red
    exit 1
}

if (Test-PortInUse -Port $backendPort) {
    Write-Host "خطأ: المنفذ $backendPort قيد الاستخدام بالفعل. لا يمكن بدء خدمة الخادم الخلفي." -ForegroundColor Red
    Write-Host "يرجى إغلاق التطبيق الذي يستخدم هذا المنفذ والمحاولة مرة أخرى." -ForegroundColor Red
    exit 1
}

# تحديد المسارات
$rootPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$projectPath = Join-Path -Path $rootPath -ChildPath "my-smart-teacher"

# محاولة بدء تشغيل خدمة Python (للميزات المتقدمة)
$pythonAvailable = $false
$pythonProcess = $null

if (Test-PortInUse -Port $pythonPort) {
    Write-Host "تحذير: المنفذ $pythonPort قيد الاستخدام بالفعل. لن يتم تشغيل خدمة Python." -ForegroundColor Yellow
    Write-Host "سيتم استخدام الخدمات البديلة في Node.js." -ForegroundColor Yellow
} else {
    Write-Host "جاري بدء تشغيل خدمة Python..." -ForegroundColor Yellow
    $pythonProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$projectPath' ; npm run python-service" -PassThru -WindowStyle Normal

    # الانتظار لحظة حتى تبدأ خدمة Python
    Start-Sleep -Seconds 5

    # التحقق مما إذا كانت خدمة Python متاحة
    try {
        $pythonHealth = Invoke-RestMethod -Uri "http://localhost:$pythonPort/health" -Method Get -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($pythonHealth.status -eq "healthy") {
            $pythonAvailable = $true
            Write-Host "تم بدء تشغيل خدمة Python بنجاح." -ForegroundColor Green
            Write-Host "رابط خدمة Python: http://localhost:$pythonPort" -ForegroundColor Green
        }
    } catch {
        Write-Host "تحذير: خدمة Python غير متاحة. سيتم استخدام الخدمات البديلة." -ForegroundColor Yellow
        if ($null -ne $pythonProcess -and -not $pythonProcess.HasExited) {
            Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
            $pythonProcess = $null
        }
    }
}

# بدء تشغيل خدمة الخادم الخلفي
Write-Host "جاري بدء تشغيل خدمة الخادم الخلفي..." -ForegroundColor Yellow
$backendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$projectPath' ; npm run backend" -PassThru -WindowStyle Normal

# الانتظار لحظة حتى تبدأ خدمة الخادم الخلفي
Start-Sleep -Seconds 5

# التحقق مما إذا كانت عملية الخادم الخلفي لا تزال قيد التشغيل
if ($null -eq $backendProcess -or $backendProcess.HasExited) {
    Write-Host "خطأ: تعذر بدء تشغيل خدمة الخادم الخلفي." -ForegroundColor Red
    # إيقاف خدمة Python إذا كانت قيد التشغيل
    if ($pythonAvailable -and $null -ne $pythonProcess) {
        Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host "تم بدء تشغيل خدمة الخادم الخلفي بنجاح." -ForegroundColor Green
Write-Host "رابط الخادم الخلفي: http://localhost:$backendPort" -ForegroundColor Green
Write-Host ""

# بدء تشغيل خدمة الواجهة الأمامية
Write-Host "جاري بدء تشغيل خدمة الواجهة الأمامية..." -ForegroundColor Yellow
$frontendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$projectPath' ; npm run frontend" -PassThru -WindowStyle Normal

# الانتظار لحظة حتى تبدأ خدمة الواجهة الأمامية
Start-Sleep -Seconds 5

# التحقق مما إذا كانت عملية الواجهة الأمامية لا تزال قيد التشغيل
if ($null -eq $frontendProcess -or $frontendProcess.HasExited) {
    Write-Host "خطأ: تعذر بدء تشغيل خدمة الواجهة الأمامية." -ForegroundColor Red
    # إيقاف الخدمات الأخرى
    if ($pythonAvailable -and $null -ne $pythonProcess) {
        Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "تم بدء تشغيل خدمة الواجهة الأمامية بنجاح." -ForegroundColor Green
Write-Host "رابط الواجهة الأمامية: http://localhost:$frontendPort" -ForegroundColor Green
Write-Host ""

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      تم بدء تشغيل الخدمات بنجاح!       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

if ($pythonAvailable) {
    Write-Host "الميزات المتقدمة متاحة:" -ForegroundColor Green
    Write-Host "- التعرف على الكلام" -ForegroundColor Green
    Write-Host "- تحليل الصور" -ForegroundColor Green
    Write-Host "- مشاركة الشاشة" -ForegroundColor Green
} else {
    Write-Host "تحذير: الميزات المتقدمة غير متاحة بسبب عدم توفر خدمة Python." -ForegroundColor Yellow
    Write-Host "سيتم استخدام الخدمات البديلة في Node.js كما هو موضح في نظام بدء التشغيل الموحد." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "للوصول إلى التطبيق، افتح المتصفح على الرابط: http://localhost:$frontendPort" -ForegroundColor Green
Write-Host ""

# مراقبة العمليات
try {
    Write-Host "اضغط على Ctrl+C لإيقاف هذا السكريبت وإغلاق جميع الخدمات..." -ForegroundColor DarkGray
    while ($true) {
        # التحقق مما إذا كانت العمليات لا تزال قيد التشغيل
        $frontendRunning = -not $frontendProcess.HasExited
        $backendRunning = -not $backendProcess.HasExited
        $pythonRunning = $pythonAvailable -and $null -ne $pythonProcess -and -not $pythonProcess.HasExited
        
        # عرض حالة الخدمات
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "      حالة خدمات معلمي الذكي       " -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "حالة خدمة الواجهة الأمامية: $(if ($frontendRunning) { 'قيد التشغيل' } else { 'متوقفة' })" -ForegroundColor $(if ($frontendRunning) { "Green" } else { "Red" })
        Write-Host "حالة خدمة الخادم الخلفي: $(if ($backendRunning) { 'قيد التشغيل' } else { 'متوقفة' })" -ForegroundColor $(if ($backendRunning) { "Green" } else { "Red" })
        Write-Host "حالة خدمة Python: $(if ($pythonRunning) { 'قيد التشغيل' } else { 'غير متاحة' })" -ForegroundColor $(if ($pythonRunning) { "Green" } else { "Yellow" })
        Write-Host ""
        Write-Host "للوصول إلى التطبيق، افتح المتصفح على الرابط: http://localhost:$frontendPort" -ForegroundColor Green
        Write-Host ""
        Write-Host "اضغط على Ctrl+C لإيقاف هذا السكريبت وإغلاق جميع الخدمات..." -ForegroundColor DarkGray
        
        # إعادة تشغيل خدمة الواجهة الأمامية إذا توقفت
        if (-not $frontendRunning) {
            Write-Host "إعادة تشغيل خدمة الواجهة الأمامية..." -ForegroundColor Yellow
            $frontendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$projectPath' ; npm run frontend" -PassThru -WindowStyle Normal
        }
        
        # إعادة تشغيل خدمة الخادم الخلفي إذا توقفت
        if (-not $backendRunning) {
            Write-Host "إعادة تشغيل خدمة الخادم الخلفي..." -ForegroundColor Yellow
            $backendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$projectPath' ; npm run backend" -PassThru -WindowStyle Normal
        }
        
        # إعادة تشغيل خدمة Python إذا توقفت وكانت متاحة سابقاً
        if ($pythonAvailable -and $null -ne $pythonProcess -and -not $pythonRunning) {
            Write-Host "إعادة تشغيل خدمة Python..." -ForegroundColor Yellow
            $pythonProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$projectPath' ; npm run python-service" -PassThru -WindowStyle Normal
        }
        
        # الانتظار قبل التحقق مرة أخرى
        Start-Sleep -Seconds 10
    }
}
finally {
    # إيقاف جميع العمليات عند الخروج
    Write-Host "إيقاف جميع الخدمات..." -ForegroundColor Yellow
    Stop-Process -Id $frontendProcess.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
    if ($pythonAvailable -and $null -ne $pythonProcess) {
        Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "تم إيقاف جميع الخدمات بنجاح." -ForegroundColor Green
}
