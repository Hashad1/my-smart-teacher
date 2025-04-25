# Simple script to deploy My Smart Teacher application to Azure

# Variables
$ResourceGroup = "my-smart-teacher-rg"
$Location = "westeurope"
$RegistryName = "mysmartteacheracr"
$rootPath = "c:\Users\alpha\Downloads\workspace"
$pythonServicePath = "$rootPath\python_service_enhanced"
$frontendPath = "$rootPath\my-smart-teacher\frontend"
$backendPath = "$rootPath\my-smart-teacher\backend"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      Deploying My Smart Teacher to Azure      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Login to Azure
Write-Host "Logging in to Azure..." -ForegroundColor Cyan
az login

# 2. Create Resource Group
Write-Host "Creating Resource Group $ResourceGroup..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location

# 3. Create Azure Container Registry
Write-Host "Creating Container Registry $RegistryName..." -ForegroundColor Yellow
az acr create --resource-group $ResourceGroup --name $RegistryName --sku Basic --admin-enabled true

# 4. Get Container Registry credentials
Write-Host "Getting Container Registry credentials..." -ForegroundColor Yellow
$credentials = az acr credential show --name $RegistryName | ConvertFrom-Json
$username = $credentials.username
$password = $credentials.passwords[0].value

# 5. Login to Container Registry
Write-Host "Logging in to Container Registry $RegistryName..." -ForegroundColor Yellow
echo $password | docker login "$RegistryName.azurecr.io" --username $username --password-stdin

# 6. Build Docker images
Write-Host "Building Frontend image..." -ForegroundColor Yellow
docker build -t "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest" $frontendPath

Write-Host "Building Backend image..." -ForegroundColor Yellow
docker build -t "$RegistryName.azurecr.io/my-smart-teacher-backend:latest" $backendPath

Write-Host "Building Python Service image..." -ForegroundColor Yellow
docker build -t "$RegistryName.azurecr.io/my-smart-teacher-python:latest" $pythonServicePath

# 7. Push images to Container Registry
Write-Host "Pushing images to Container Registry..." -ForegroundColor Yellow
docker push "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest"
docker push "$RegistryName.azurecr.io/my-smart-teacher-backend:latest"
docker push "$RegistryName.azurecr.io/my-smart-teacher-python:latest"

# 8. Create Container Apps environment
Write-Host "Creating Container Apps environment..." -ForegroundColor Yellow
az containerapp env create --name "my-smart-teacher-env" --resource-group $ResourceGroup --location $Location

# 9. Deploy Python Service app
Write-Host "Deploying Python Service app..." -ForegroundColor Yellow
az containerapp create --name "python-service" --resource-group $ResourceGroup --environment "my-smart-teacher-env" --image "$RegistryName.azurecr.io/my-smart-teacher-python:latest" --registry-server "$RegistryName.azurecr.io" --registry-username $username --registry-password $password --target-port 8085 --ingress "external"

# 10. Get Python Service URL
$pythonServiceUrl = az containerapp show --name "python-service" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv

# 11. Deploy Backend app
Write-Host "Deploying Backend app..." -ForegroundColor Yellow
az containerapp create --name "backend" --resource-group $ResourceGroup --environment "my-smart-teacher-env" --image "$RegistryName.azurecr.io/my-smart-teacher-backend:latest" --registry-server "$RegistryName.azurecr.io" --registry-username $username --registry-password $password --target-port 3000 --ingress "external" --env-vars "PYTHON_SERVICE_URL=https://$pythonServiceUrl"

# 12. Get Backend URL
$backendUrl = az containerapp show --name "backend" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv

# 13. Deploy Frontend app
Write-Host "Deploying Frontend app..." -ForegroundColor Yellow
az containerapp create --name "frontend" --resource-group $ResourceGroup --environment "my-smart-teacher-env" --image "$RegistryName.azurecr.io/my-smart-teacher-frontend:latest" --registry-server "$RegistryName.azurecr.io" --registry-username $username --registry-password $password --target-port 80 --ingress "external" --env-vars "VITE_API_URL=https://$backendUrl" "VITE_PYTHON_SERVICE_URL=https://$pythonServiceUrl"

# 14. Get Frontend URL
$frontendUrl = az containerapp show --name "frontend" --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv

# 15. Display deployment information
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      My Smart Teacher Deployment Information      " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application successfully deployed to Azure Container Apps!" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Yellow
Write-Host "- Frontend: https://$frontendUrl" -ForegroundColor Green
Write-Host "- Backend: https://$backendUrl" -ForegroundColor Green
Write-Host "- Python Service: https://$pythonServiceUrl" -ForegroundColor Green
Write-Host "- Screen Share: https://$pythonServiceUrl/screen-share" -ForegroundColor Green
Write-Host ""

Write-Host "Deployment completed!" -ForegroundColor Cyan
