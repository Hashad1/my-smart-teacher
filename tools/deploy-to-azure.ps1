# سكربت نشر تطبيق معلمي الذكي على Azure
# يجب تشغيل هذا السكربت بعد تثبيت Azure CLI و Docker

# متغيرات يمكن تعديلها
$resourceGroupName = "my-smart-teacher-rg"
$location = "westeurope"
$acrName = "mysmartteacheracr"
$envName = "my-smart-teacher-env"

# دالة لعرض رسائل بألوان
function Write-ColoredMessage {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    Write-Host $Message -ForegroundColor $Color
}

# التحقق من تثبيت Azure CLI
Write-ColoredMessage "التحقق من تثبيت Azure CLI..." "Yellow"
$azCliVersion = az --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "لم يتم العثور على Azure CLI. يرجى تثبيته من https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" "Red"
    exit 1
}
Write-ColoredMessage "تم العثور على Azure CLI" "Green"

# التحقق من تثبيت Docker
Write-ColoredMessage "التحقق من تثبيت Docker..." "Yellow"
$dockerVersion = docker --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "لم يتم العثور على Docker. يرجى تثبيته من https://docs.docker.com/get-docker/" "Red"
    exit 1
}
Write-ColoredMessage "تم العثور على Docker" "Green"

# تسجيل الدخول إلى Azure
Write-ColoredMessage "تسجيل الدخول إلى Azure..." "Yellow"
az login
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل تسجيل الدخول إلى Azure" "Red"
    exit 1
}
Write-ColoredMessage "تم تسجيل الدخول بنجاح" "Green"

# إنشاء مجموعة موارد
Write-ColoredMessage "إنشاء مجموعة موارد $resourceGroupName..." "Yellow"
az group create --name $resourceGroupName --location $location
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل إنشاء مجموعة الموارد" "Red"
    exit 1
}
Write-ColoredMessage "تم إنشاء مجموعة الموارد بنجاح" "Green"

# إنشاء سجل حاويات Azure
Write-ColoredMessage "إنشاء سجل حاويات Azure $acrName..." "Yellow"
az acr create --resource-group $resourceGroupName --name $acrName --sku Basic --admin-enabled true
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل إنشاء سجل الحاويات" "Red"
    exit 1
}
Write-ColoredMessage "تم إنشاء سجل الحاويات بنجاح" "Green"

# الحصول على بيانات اعتماد سجل الحاويات
Write-ColoredMessage "الحصول على بيانات اعتماد سجل الحاويات..." "Yellow"
$acrCredentials = az acr credential show --name $acrName | ConvertFrom-Json
$acrUsername = $acrCredentials.username
$acrPassword = $acrCredentials.passwords[0].value
$acrLoginServer = "$acrName.azurecr.io"

Write-ColoredMessage "تم الحصول على بيانات الاعتماد بنجاح" "Green"
Write-ColoredMessage "اسم المستخدم: $acrUsername" "Cyan"
Write-ColoredMessage "عنوان السجل: $acrLoginServer" "Cyan"

# تسجيل الدخول إلى سجل الحاويات
Write-ColoredMessage "تسجيل الدخول إلى سجل الحاويات..." "Yellow"
echo $acrPassword | docker login $acrLoginServer -u $acrUsername --password-stdin
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل تسجيل الدخول إلى سجل الحاويات" "Red"
    exit 1
}
Write-ColoredMessage "تم تسجيل الدخول إلى سجل الحاويات بنجاح" "Green"

# بناء صور Docker
Write-ColoredMessage "بناء صور Docker..." "Yellow"
docker-compose build
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل بناء صور Docker" "Red"
    exit 1
}
Write-ColoredMessage "تم بناء صور Docker بنجاح" "Green"

# إعادة تسمية الصور للنشر
Write-ColoredMessage "إعادة تسمية الصور للنشر..." "Yellow"
docker tag workspace_frontend:latest "$acrLoginServer/my-smart-teacher-frontend:latest"
docker tag workspace_backend:latest "$acrLoginServer/my-smart-teacher-backend:latest"
docker tag workspace_python-service:latest "$acrLoginServer/my-smart-teacher-python:latest"
Write-ColoredMessage "تم إعادة تسمية الصور بنجاح" "Green"

# دفع الصور إلى سجل الحاويات
Write-ColoredMessage "دفع الصور إلى سجل الحاويات..." "Yellow"
docker push "$acrLoginServer/my-smart-teacher-frontend:latest"
docker push "$acrLoginServer/my-smart-teacher-backend:latest"
docker push "$acrLoginServer/my-smart-teacher-python:latest"
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل دفع الصور إلى سجل الحاويات" "Red"
    exit 1
}
Write-ColoredMessage "تم دفع الصور إلى سجل الحاويات بنجاح" "Green"

# إنشاء بيئة Container Apps
Write-ColoredMessage "إنشاء بيئة Container Apps..." "Yellow"
az containerapp env create `
  --name $envName `
  --resource-group $resourceGroupName `
  --location $location
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل إنشاء بيئة Container Apps" "Red"
    exit 1
}
Write-ColoredMessage "تم إنشاء بيئة Container Apps بنجاح" "Green"

# الحصول على اسم النطاق الأساسي
$domainName = az containerapp env show --name $envName --resource-group $resourceGroupName --query "properties.defaultDomain" -o tsv

# نشر تطبيق الواجهة الأمامية
Write-ColoredMessage "نشر تطبيق الواجهة الأمامية..." "Yellow"
az containerapp create `
  --name frontend `
  --resource-group $resourceGroupName `
  --environment $envName `
  --image "$acrLoginServer/my-smart-teacher-frontend:latest" `
  --target-port 80 `
  --ingress external `
  --registry-server $acrLoginServer `
  --registry-username $acrUsername `
  --registry-password $acrPassword `
  --env-vars "VITE_API_URL=https://backend.$domainName" "VITE_PYTHON_SERVICE_URL=https://python-service.$domainName"
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل نشر تطبيق الواجهة الأمامية" "Red"
    exit 1
}
Write-ColoredMessage "تم نشر تطبيق الواجهة الأمامية بنجاح" "Green"

# نشر تطبيق الخادم الخلفي
Write-ColoredMessage "نشر تطبيق الخادم الخلفي..." "Yellow"
az containerapp create `
  --name backend `
  --resource-group $resourceGroupName `
  --environment $envName `
  --image "$acrLoginServer/my-smart-teacher-backend:latest" `
  --target-port 3001 `
  --ingress external `
  --registry-server $acrLoginServer `
  --registry-username $acrUsername `
  --registry-password $acrPassword `
  --env-vars "NODE_ENV=production" "PORT=3001" "PYTHON_SERVICE_URL=https://python-service.$domainName"
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل نشر تطبيق الخادم الخلفي" "Red"
    exit 1
}
Write-ColoredMessage "تم نشر تطبيق الخادم الخلفي بنجاح" "Green"

# نشر تطبيق خدمة Python
Write-ColoredMessage "نشر تطبيق خدمة Python..." "Yellow"
az containerapp create `
  --name python-service `
  --resource-group $resourceGroupName `
  --environment $envName `
  --image "$acrLoginServer/my-smart-teacher-python:latest" `
  --target-port 8085 `
  --ingress external `
  --registry-server $acrLoginServer `
  --registry-username $acrUsername `
  --registry-password $acrPassword `
  --env-vars "FLASK_ENV=production" "PORT=8085"
if ($LASTEXITCODE -ne 0) {
    Write-ColoredMessage "فشل نشر تطبيق خدمة Python" "Red"
    exit 1
}
Write-ColoredMessage "تم نشر تطبيق خدمة Python بنجاح" "Green"

# عرض روابط الوصول
$frontendUrl = "https://frontend.$domainName"
$backendUrl = "https://backend.$domainName"
$pythonServiceUrl = "https://python-service.$domainName"

Write-ColoredMessage "====================================================" "Cyan"
Write-ColoredMessage "      تم نشر تطبيق معلمي الذكي بنجاح على Azure      " "Cyan"
Write-ColoredMessage "====================================================" "Cyan"
Write-ColoredMessage ""
Write-ColoredMessage "روابط الوصول:" "Yellow"
Write-ColoredMessage "الواجهة الأمامية: $frontendUrl" "Green"
Write-ColoredMessage "الخادم الخلفي: $backendUrl" "Green"
Write-ColoredMessage "خدمة Python: $pythonServiceUrl" "Green"
Write-ColoredMessage ""
Write-ColoredMessage "لمزيد من المعلومات حول إدارة التطبيق، راجع ملف AZURE_DEPLOYMENT.md" "Cyan"
