# سكريبت مبسط لنشر تطبيق معلمي الذكي على Azure

# المتغيرات
$ResourceGroup = "my-smart-teacher-rg"
$Location = "westeurope"
$RegistryName = "mysmartteacheracr"
$rootPath = "c:\Users\alpha\Downloads\workspace"
$pythonServicePath = "$rootPath\python_service_enhanced"
$frontendPath = "$rootPath\my-smart-teacher\frontend"
$backendPath = "$rootPath\my-smart-teacher\backend"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      نشر تطبيق معلمي الذكي على Azure      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# 1. تسجيل الدخول إلى Azure
Write-Host "تسجيل الدخول إلى Azure..." -ForegroundColor Cyan
az login

# 2. إنشاء مجموعة الموارد
Write-Host "إنشاء مجموعة الموارد $ResourceGroup..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location

# 3. إنشاء سجل الحاويات
Write-Host "إنشاء سجل الحاويات $RegistryName..." -ForegroundColor Yellow
az acr create --resource-group $ResourceGroup --name $RegistryName --sku Basic --admin-enabled true

# 4. الحصول على بيانات اعتماد سجل الحاويات
Write-Host "الحصول على بيانات اعتماد سجل الحاويات..." -ForegroundColor Yellow
$credentials = az acr credential show --name $RegistryName | ConvertFrom-Json
$username = $credentials.username
$password = $credentials.passwords[0].value

# 5. تسجيل الدخول إلى سجل الحاويات
Write-Host "تسجيل الدخول إلى سجل الحاويات $RegistryName..." -ForegroundColor Yellow
echo $password | docker login "$RegistryName.azurecr.io" --username $username --password-stdin

# 6. بناء صور Docker
Write-Host "بناء صورة الواجهة الأمامية..." -ForegroundColor Yellow
docker build -t "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest" $frontendPath

Write-Host "بناء صورة الخادم الخلفي..." -ForegroundColor Yellow
docker build -t "$RegistryName.azurecr.io/my-smart-teacher-backend:latest" $backendPath

Write-Host "بناء صورة خدمة Python المحسنة..." -ForegroundColor Yellow
docker build -t "$RegistryName.azurecr.io/my-smart-teacher-python:latest" $pythonServicePath

# 7. دفع الصور إلى سجل الحاويات
Write-Host "دفع الصور إلى سجل الحاويات..." -ForegroundColor Yellow
docker push "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest"
docker push "$RegistryName.azurecr.io/my-smart-teacher-backend:latest"
docker push "$RegistryName.azurecr.io/my-smart-teacher-python:latest"

# 8. إنشاء بيئة تطبيقات الحاويات
Write-Host "إنشاء بيئة تطبيقات الحاويات..." -ForegroundColor Yellow
az containerapp env create --name "my-smart-teacher-env" --resource-group $ResourceGroup --location $Location

# 9. نشر تطبيق خدمة Python
Write-Host "إنشاء تطبيق خدمة Python..." -ForegroundColor Yellow
az containerapp create --name "python-service" --resource-group $ResourceGroup --environment "my-smart-teacher-env" --image "$RegistryName.azurecr.io/my-smart-teacher-python:latest" --registry-server "$RegistryName.azurecr.io" --registry-username $username --registry-password $password --target-port 8085 --ingress "external"

# 10. الحصول على عنوان URL لخدمة Python
$pythonServiceUrl = az containerapp show --name "python-service" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv

# 11. نشر تطبيق الخادم الخلفي
Write-Host "إنشاء تطبيق الخادم الخلفي..." -ForegroundColor Yellow
az containerapp create --name "backend" --resource-group $ResourceGroup --environment "my-smart-teacher-env" --image "$RegistryName.azurecr.io/my-smart-teacher-backend:latest" --registry-server "$RegistryName.azurecr.io" --registry-username $username --registry-password $password --target-port 3000 --ingress "external" --env-vars "PYTHON_SERVICE_URL=https://$pythonServiceUrl"

# 12. الحصول على عنوان URL للخادم الخلفي
$backendUrl = az containerapp show --name "backend" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv

# 13. نشر تطبيق الواجهة الأمامية
Write-Host "إنشاء تطبيق الواجهة الأمامية..." -ForegroundColor Yellow
az containerapp create --name "frontend" --resource-group $ResourceGroup --environment "my-smart-teacher-env" --image "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest" --registry-server "$RegistryName.azurecr.io" --registry-username $username --registry-password $password --target-port 80 --ingress "external" --env-vars "VITE_API_URL=https://$backendUrl" "VITE_PYTHON_SERVICE_URL=https://$pythonServiceUrl"

# 14. الحصول على عنوان URL للواجهة الأمامية
$frontendUrl = az containerapp show --name "frontend" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv

# 15. عرض معلومات النشر
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      معلومات نشر تطبيق معلمي الذكي      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "تم نشر التطبيق بنجاح على Azure Container Apps!" -ForegroundColor Green
Write-Host ""
Write-Host "روابط الوصول إلى التطبيق:" -ForegroundColor Yellow
Write-Host "- الواجهة الأمامية: https://$frontendUrl" -ForegroundColor Green
Write-Host "- الخادم الخلفي: https://$backendUrl" -ForegroundColor Green
Write-Host "- خدمة Python: https://$pythonServiceUrl" -ForegroundColor Green
Write-Host "- مشاركة الشاشة: https://$pythonServiceUrl/screen-share" -ForegroundColor Green
Write-Host ""

Write-Host "تم الانتهاء من عملية النشر!" -ForegroundColor Cyan
