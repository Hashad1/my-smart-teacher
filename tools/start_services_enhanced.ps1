# سكريبت محسن لبدء خدمات معلمي الذكي
# يقوم هذا السكريبت بتشغيل كل من خدمة Node.js وخدمة Python المحسنة

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      بدء تشغيل خدمات معلمي الذكي المحسنة       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# تحديد المسارات
$rootPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$pythonServicePath = Join-Path -Path $rootPath -ChildPath "python_service_enhanced"
$frontendPath = Join-Path -Path $rootPath -ChildPath "my-smart-teacher\frontend"
$backendPath = Join-Path -Path $rootPath -ChildPath "my-smart-teacher\backend"

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
$pythonPort = 8085

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

if (Test-PortInUse -Port $pythonPort) {
    Write-Host "خطأ: المنفذ $pythonPort قيد الاستخدام بالفعل. لا يمكن بدء خدمة Python." -ForegroundColor Red
    Write-Host "يرجى إغلاق التطبيق الذي يستخدم هذا المنفذ والمحاولة مرة أخرى." -ForegroundColor Red
    exit 1
}

# بدء تشغيل خدمة Python المحسنة أولاً
Write-Host "جاري بدء تشغيل خدمة Python المحسنة..." -ForegroundColor Yellow
$pythonProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$pythonServicePath' ; python app.py" -PassThru -WindowStyle Normal

# الانتظار لحظة حتى تبدأ خدمة Python
Start-Sleep -Seconds 5

# التحقق مما إذا كانت عملية Python لا تزال قيد التشغيل
if ($null -eq $pythonProcess -or $pythonProcess.HasExited) {
    Write-Host "خطأ: تعذر بدء تشغيل خدمة Python المحسنة." -ForegroundColor Red
    exit 1
}

Write-Host "تم بدء تشغيل خدمة Python المحسنة بنجاح." -ForegroundColor Green
Write-Host "رابط خدمة Python: http://localhost:$pythonPort" -ForegroundColor Green
Write-Host "رابط مشاركة الشاشة: http://localhost:$pythonPort/screen-share" -ForegroundColor Green
Write-Host ""

# بدء تشغيل خدمة الخادم الخلفي
Write-Host "جاري بدء تشغيل خدمة الخادم الخلفي..." -ForegroundColor Yellow
$backendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$backendPath' ; npm run dev" -PassThru -WindowStyle Normal

# الانتظار لحظة حتى تبدأ خدمة الخادم الخلفي
Start-Sleep -Seconds 5

# التحقق مما إذا كانت عملية الخادم الخلفي لا تزال قيد التشغيل
if ($null -eq $backendProcess -or $backendProcess.HasExited) {
    Write-Host "خطأ: تعذر بدء تشغيل خدمة الخادم الخلفي." -ForegroundColor Red
    # إيقاف خدمة Python
    Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "تم بدء تشغيل خدمة الخادم الخلفي بنجاح." -ForegroundColor Green
Write-Host "رابط الخادم الخلفي: http://localhost:$backendPort" -ForegroundColor Green
Write-Host ""

# بدء تشغيل خدمة الواجهة الأمامية
Write-Host "جاري بدء تشغيل خدمة الواجهة الأمامية..." -ForegroundColor Yellow
$frontendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$frontendPath' ; npm run dev" -PassThru -WindowStyle Normal

# الانتظار لحظة حتى تبدأ خدمة الواجهة الأمامية
Start-Sleep -Seconds 5

# التحقق مما إذا كانت عملية الواجهة الأمامية لا تزال قيد التشغيل
if ($null -eq $frontendProcess -or $frontendProcess.HasExited) {
    Write-Host "خطأ: تعذر بدء تشغيل خدمة الواجهة الأمامية." -ForegroundColor Red
    # إيقاف الخدمات الأخرى
    Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "تم بدء تشغيل خدمة الواجهة الأمامية بنجاح." -ForegroundColor Green
Write-Host "رابط الواجهة الأمامية: http://localhost:$frontendPort" -ForegroundColor Green
Write-Host ""

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      تم بدء تشغيل جميع الخدمات بنجاح!       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "للوصول إلى التطبيق، افتح المتصفح على الرابط: http://localhost:$frontendPort" -ForegroundColor Green
Write-Host "للوصول إلى واجهة مشاركة الشاشة، افتح المتصفح على الرابط: http://localhost:$pythonPort/screen-share" -ForegroundColor Green
Write-Host ""

# مراقبة العمليات
try {
    Write-Host "اضغط على Ctrl+C لإيقاف هذا السكريبت وإغلاق جميع الخدمات..." -ForegroundColor DarkGray
    while ($true) {
        # التحقق مما إذا كانت العمليات لا تزال قيد التشغيل
        $pythonRunning = -not $pythonProcess.HasExited
        $backendRunning = -not $backendProcess.HasExited
        $frontendRunning = -not $frontendProcess.HasExited
        
        # عرض حالة الخدمات
        $status = @(
            "حالة خدمة Python: $(if ($pythonRunning) { 'قيد التشغيل' } else { 'متوقفة' })",
            "حالة خدمة الخادم الخلفي: $(if ($backendRunning) { 'قيد التشغيل' } else { 'متوقفة' })",
            "حالة خدمة الواجهة الأمامية: $(if ($frontendRunning) { 'قيد التشغيل' } else { 'متوقفة' })"
        )
        
        Clear-Host
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host "      حالة خدمات معلمي الذكي المحسنة       " -ForegroundColor Cyan
        Write-Host "====================================================" -ForegroundColor Cyan
        Write-Host ""
        $status | ForEach-Object { Write-Host $_ -ForegroundColor $(if ($_ -like "*قيد التشغيل*") { "Green" } else { "Red" }) }
        Write-Host ""
        Write-Host "للوصول إلى التطبيق، افتح المتصفح على الرابط: http://localhost:$frontendPort" -ForegroundColor Green
        Write-Host "للوصول إلى واجهة مشاركة الشاشة، افتح المتصفح على الرابط: http://localhost:$pythonPort/screen-share" -ForegroundColor Green
        Write-Host ""
        Write-Host "اضغط على Ctrl+C لإيقاف هذا السكريبت وإغلاق جميع الخدمات..." -ForegroundColor DarkGray
        
        # إعادة تشغيل أي خدمة متوقفة
        if (-not $pythonRunning) {
            Write-Host "إعادة تشغيل خدمة Python..." -ForegroundColor Yellow
            $pythonProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$pythonServicePath' ; python app.py" -PassThru -WindowStyle Normal
        }
        
        if (-not $backendRunning) {
            Write-Host "إعادة تشغيل خدمة الخادم الخلفي..." -ForegroundColor Yellow
            $backendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$backendPath' ; npm run dev" -PassThru -WindowStyle Normal
        }
        
        if (-not $frontendRunning) {
            Write-Host "إعادة تشغيل خدمة الواجهة الأمامية..." -ForegroundColor Yellow
            $frontendProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$frontendPath' ; npm run dev" -PassThru -WindowStyle Normal
        }
        
        # الانتظار قبل التحقق مرة أخرى
        Start-Sleep -Seconds 10
    }
}
finally {
    # إيقاف جميع العمليات عند الخروج
    Write-Host "إيقاف جميع الخدمات..." -ForegroundColor Yellow
    Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $backendProcess.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $frontendProcess.Id -Force -ErrorAction SilentlyContinue
    Write-Host "تم إيقاف جميع الخدمات بنجاح." -ForegroundColor Green
}
