# سكريبت لإصلاح مشكلات تنسيق Markdown في ملفات التوثيق
# يقوم هذا السكريبت بإصلاح المشكلات الشائعة في ملفات Markdown مثل:
# - إضافة سطور فارغة حول العناوين والقوائم وكتل الكود
# - إزالة علامات الترقيم من نهاية العناوين
# - إضافة تحديد لغة البرمجة في كتل الكود
# - تصحيح ترقيم القوائم المرقمة
# - تنسيق روابط URL

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      إصلاح مشكلات تنسيق Markdown       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# تحديد المسار الجذر للمشروع
$rootPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Write-Host "مسار المشروع: $rootPath" -ForegroundColor Yellow
Write-Host ""

# الحصول على جميع ملفات Markdown في المشروع
$markdownFiles = Get-ChildItem -Path $rootPath -Filter "*.md" -Recurse -File

Write-Host "تم العثور على $($markdownFiles.Count) ملف Markdown للمعالجة." -ForegroundColor Green
Write-Host ""

# عداد للملفات التي تم تعديلها
$modifiedFilesCount = 0

foreach ($file in $markdownFiles) {
    Write-Host "معالجة ملف: $($file.FullName)" -ForegroundColor Yellow
    
    # قراءة محتوى الملف
    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content
    
    # إصلاح MD022: إضافة سطور فارغة حول العناوين
    $content = $content -replace '(\r?\n)([#]{1,6} .+?)(\r?\n[^#\r\n])', '$1$2$3$3'
    $content = $content -replace '([^#\r\n]\r?\n)([#]{1,6} .+?)(\r?\n)', '$1$1$2$3'
    
    # إصلاح MD026: إزالة علامات الترقيم من نهاية العناوين
    $content = $content -replace '(^|\r?\n)([#]{1,6} .+?)[:;,.!?]+(\r?\n|$)', '$1$2$3'
    
    # إصلاح MD032: إضافة سطور فارغة حول القوائم
    $content = $content -replace '(\r?\n)([0-9]+\. .+?)(\r?\n[^0-9\r\n])', '$1$2$3$3'
    $content = $content -replace '([^0-9\r\n]\r?\n)([0-9]+\. .+?)(\r?\n)', '$1$1$2$3'
    $content = $content -replace '(\r?\n)(- .+?)(\r?\n[^-\r\n])', '$1$2$3$3'
    $content = $content -replace '([^-\r\n]\r?\n)(- .+?)(\r?\n)', '$1$1$2$3'
    
    # إصلاح MD031: إضافة سطور فارغة حول كتل الكود
    $content = $content -replace '(\r?\n)(```.*?)(\r?\n)', '$1$1$2$3'
    $content = $content -replace '(\r?\n)(```\s*)(\r?\n)', '$1$2$3$3'
    
    # إصلاح MD040: إضافة تحديد لغة البرمجة في كتل الكود
    $content = $content -replace '(\r?\n)```(\r?\n)', '$1```text$2'
    
    # إصلاح MD034: تنسيق روابط URL
    $content = $content -replace '(\s)(https?:\/\/[^\s]+)(\s)', '$1<$2>$3'
    
    # إصلاح MD047: التأكد من وجود سطر فارغ في نهاية الملف
    if (-not $content.EndsWith("`n")) {
        $content += "`n"
    }
    
    # حفظ التغييرات إذا تم تعديل المحتوى
    if ($content -ne $originalContent) {
        $content | Set-Content -Path $file.FullName -NoNewline
        Write-Host "  تم إصلاح مشكلات التنسيق في الملف." -ForegroundColor Green
        $modifiedFilesCount++
    } else {
        Write-Host "  لم يتم العثور على مشكلات تنسيق في الملف." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      اكتملت عملية إصلاح مشكلات التنسيق       " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "تم إصلاح $modifiedFilesCount من أصل $($markdownFiles.Count) ملف Markdown." -ForegroundColor Green
Write-Host ""
Write-Host "ملاحظة: قد تظل بعض المشكلات المعقدة تتطلب إصلاحًا يدويًا." -ForegroundColor Yellow
Write-Host "يرجى مراجعة الملفات المعدلة للتأكد من صحة التنسيق." -ForegroundColor Yellow
