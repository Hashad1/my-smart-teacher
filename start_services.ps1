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
$nodePort = 3000
$pythonPort = 8085

if (Test-PortInUse -Port $nodePort) {
    Write-Host "خطأ: المنفذ $nodePort قيد الاستخدام بالفعل. لا يمكن بدء خدمة Node.js." -ForegroundColor Red
    Write-Host "يرجى إغلاق التطبيق الذي يستخدم هذا المنفذ والمحاولة مرة أخرى." -ForegroundColor Red
    exit 1
}

if (Test-PortInUse -Port $pythonPort) {
    Write-Host "خطأ: المنفذ $pythonPort قيد الاستخدام بالفعل. لا يمكن بدء خدمة Python." -ForegroundColor Red
    Write-Host "يرجى إغلاق التطبيق الذي يستخدم هذا المنفذ والمحاولة مرة أخرى." -ForegroundColor Red
    exit 1
}

# بدء تشغيل خدمة Node.js في نافذة جديدة
Write-Host "جاري بدء تشغيل خدمة Node.js (الواجهة الأمامية + الخلفية)..." -ForegroundColor Yellow
$nodeProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$PSScriptRoot\my-smart-teacher' ; npm run dev" -PassThru -WindowStyle Normal

# الانتظار لحظة حتى تبدأ خدمة Node.js
Start-Sleep -Seconds 3

# التحقق مما إذا كانت عملية Node.js لا تزال قيد التشغيل
if ($null -eq $nodeProcess -or $nodeProcess.HasExited) {
    Write-Host "خطأ: تعذر بدء تشغيل خدمة Node.js." -ForegroundColor Red
    exit 1
}

Write-Host "تم بدء تشغيل خدمة Node.js بنجاح." -ForegroundColor Green
Write-Host "رابط الواجهة الأمامية: http://localhost:3000" -ForegroundColor Green
Write-Host "رابط الواجهة الخلفية: http://localhost:3000/api" -ForegroundColor Green
Write-Host ""

# بدء تشغيل خدمة Python في نافذة جديدة
Write-Host "جاري بدء تشغيل خدمة Python..." -ForegroundColor Yellow
$pythonProcess = Start-Process -FilePath "powershell" -ArgumentList "-Command", "cd '$PSScriptRoot\python_service' ; python start_service.py" -PassThru -WindowStyle Normal

# الانتظار لحظة حتى تبدأ خدمة Python
Start-Sleep -Seconds 5

# التحقق مما إذا كانت عملية Python لا تزال قيد التشغيل
if ($null -eq $pythonProcess -or $pythonProcess.HasExited) {
    Write-Host "تحذير: من المحتمل أن خدمة Python لم تبدأ بشكل صحيح." -ForegroundColor Yellow
    Write-Host "سيستمر النظام في العمل مع وظائف محدودة." -ForegroundColor Yellow
} else {
    Write-Host "تم بدء تشغيل خدمة Python بنجاح." -ForegroundColor Green
    Write-Host "رابط خدمة Python: http://localhost:8085/api" -ForegroundColor Green
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      تم بدء تشغيل جميع الخدمات        " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "لإيقاف الخدمات، أغلق نوافذ PowerShell أو اضغط على Ctrl+C في كل منها." -ForegroundColor White
Write-Host ""

# الحفاظ على تشغيل السكريبت
try {
    Write-Host "اضغط على Ctrl+C لإيقاف هذا السكريبت للمراقبة..." -ForegroundColor DarkGray
    while ($true) {
        # التحقق مما إذا كانت العمليات لا تزال قيد التشغيل
        $nodeRunning = -not $nodeProcess.HasExited
        $pythonRunning = ($null -ne $pythonProcess) -and (-not $pythonProcess.HasExited)
        
        # عرض الحالة الحالية
        Write-Host "`rالحالة: Node.js: " -NoNewline -ForegroundColor DarkGray
        if ($nodeRunning) {
            Write-Host "نشط" -NoNewline -ForegroundColor Green
        } else {
            Write-Host "متوقف" -NoNewline -ForegroundColor Red
        }
        
        Write-Host " | Python: " -NoNewline -ForegroundColor DarkGray
        if ($pythonRunning) {
            Write-Host "نشط" -NoNewline -ForegroundColor Green
        } else {
            Write-Host "متوقف" -NoNewline -ForegroundColor Red
        }
        
        # إذا توقفت كلتا الخدمتين، فالخروج من الحلقة
        if (-not $nodeRunning -and -not $pythonRunning) {
            Write-Host "`nتم إيقاف جميع الخدمات." -ForegroundColor Yellow
            break
        }
        
        Start-Sleep -Seconds 5
    }
} finally {
    # محاولة إيقاف العمليات إذا كانت لا تزال قيد التشغيل
    if ($null -ne $nodeProcess -and -not $nodeProcess.HasExited) {
        $nodeProcess.Kill()
    }
    
    if ($null -ne $pythonProcess -and -not $pythonProcess.HasExited) {
        $pythonProcess.Kill()
    }
    
    Write-Host "تم إيقاف جميع الخدمات." -ForegroundColor Yellow
}
