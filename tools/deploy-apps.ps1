# Script to deploy My Smart Teacher application to Azure Container Apps

# Variables
$resourceGroup = "my-smart-teacher-rg"
$envName = "managedEnvironment-mysmartteacherr-8c55"
$location = "uaenorth"
$acrName = "mysmartteacheracr"
$subscriptionId = "0314a098-4273-406c-87a0-ff4c8f96d791"

# API Keys and Environment Variables
$geminiApiKey = "$env:GEMINI_API_KEY"
$pineconeApiKey = "$env:PINECONE_API_KEY"
$openaiApiKey = "$env:OPENAI_API_KEY"
$openRouterKey = "$env:OPEN_ROUTER_KEY"
$googleVirtexaiApiKey = "$env:GOOGLE_VIRTEXAI_API_KEY"
$serpApiKey = "$env:SERP_API_KEY"
$elevenlabsApiKey = "$env:ELEVENLABS_API_KEY"
$googleGenerativeAiApiKey = "$env:GOOGLE_GENERATIVE_AI_API_KEY"
$perplexityApiKey = "$env:PERPLEXITY_API_KEY"
$groqApiKey = "$env:GROQ_API_KEY"
$xaiApiKey = "$env:XAI_API_KEY"
$serpirApiKey = "$env:SERPIR_API_KEY"

# Get ACR credentials
$acrCredentials = az acr credential show --name $acrName | ConvertFrom-Json
$acrUsername = $acrCredentials.username
$acrPassword = $acrCredentials.passwords[0].value

Write-Host "Starting deployment of My Smart Teacher applications..."

# Deploy Python Service
Write-Host "Deploying Python Service..."
az containerapp create `
  --name python-service `
  --resource-group $resourceGroup `
  --environment $envName `
  --image "$acrName.azurecr.io/my-smart-teacher-python:latest" `
  --registry-server "$acrName.azurecr.io" `
  --registry-username $acrUsername `
  --registry-password $acrPassword `
  --target-port 8085 `
  --ingress external `
  --env-vars "FLASK_ENV=production" "PORT=8085" "PYTHONUNBUFFERED=1" "ENABLE_SPEECH_RECOGNITION=true" "ENABLE_OCR=true" "ENABLE_SCREEN_SHARING=true" "ENABLE_OPENAI_INTEGRATION=true" "ARABIC_LANGUAGE_SUPPORT=true" `
    "GEMINI_API=$geminiApiKey" "PINECONE_API_KEY=$pineconeApiKey" "OPENAI_API_KEY=$openaiApiKey" "OPEN_ROUTER_KEY=$openRouterKey" `
    "GOOGLE_VIRTEXAI_API_KEY=$googleVirtexaiApiKey" "SERP_API_KEY=$serpApiKey" "ELEVENLABS_API_KEY=$elevenlabsApiKey" `
    "GOOGLE_GENERATIVE_AI_API_KEY=$googleGenerativeAiApiKey" "PERPLEXITY_API_KEY=$perplexityApiKey" "GROQ_API_KEY=$groqApiKey" `
    "XAI_API_KEY=$xaiApiKey" "SERPIR_API_KEY=$serpirApiKey"

# Get Python Service URL
$pythonServiceUrl = az containerapp show `
  --name python-service `
  --resource-group $resourceGroup `
  --query "properties.configuration.ingress.fqdn" -o tsv

Write-Host "Python Service URL: $pythonServiceUrl"

# Configure Python Service with more resources for screen sharing and image analysis
Write-Host "Configuring Python Service with additional resources..."
az containerapp update `
  --name python-service `
  --resource-group $resourceGroup `
  --cpu 1.0 `
  --memory 2.0Gi `
  --min-replicas 1 `
  --max-replicas 3 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 30

# Deploy Backend
Write-Host "Deploying Backend..."
az containerapp create `
  --name backend `
  --resource-group $resourceGroup `
  --environment $envName `
  --image "$acrName.azurecr.io/my-smart-teacher-backend:latest" `
  --registry-server "$acrName.azurecr.io" `
  --registry-username $acrUsername `
  --registry-password $acrPassword `
  --target-port 3000 `
  --ingress external `
  --env-vars "PORT=3000" "NODE_ENV=production" "PYTHON_SERVICE_URL=https://$pythonServiceUrl" "JWT_SECRET=4b7101ffd4fc47f3009d1f66c554b459e41fce59766eb244dad9d813a0f5faed8f02962a2cee141e94268083993c834cadb3f8ca624f8620c569bca91fd40e1095b2dcad0bae5bb151be2e09480bed4fd2c4b96f3ab69e86ccbfdc9d082ead99e0b952739a19ff57794b386c3ad85bd57d5c31edfc0aae18e4e644ce31f90115145967e6ab4e1fa16baef22bbe32aadad5af89269d02ad05f7a666e0b1d8ad40f2291ca55cf9da99c2220340c9e7899659fe6dd79098849bd32e750a0bdc5c1095fff4d66db9bb7648b49442cc8040bd717f126ba21c3979c32ad3c0abf678d0ffea1686b8ea7243a8349b420401dd46c3d650ba934639f6110628bb11986558" "ENABLE_AI_FEATURES=true" "ENABLE_FALLBACK=true" `
    "OPENAI_API_KEY=$openaiApiKey" "GOOGLE_GENERATIVE_AI_API_KEY=$googleGenerativeAiApiKey"

# Get Backend URL
$backendUrl = az containerapp show `
  --name backend `
  --resource-group $resourceGroup `
  --query "properties.configuration.ingress.fqdn" -o tsv

Write-Host "Backend URL: $backendUrl"

# Deploy Frontend
Write-Host "Deploying Frontend..."
az containerapp create `
  --name frontend `
  --resource-group $resourceGroup `
  --environment $envName `
  --image "$acrName.azurecr.io/my-smart-teacher-frontend:latest" `
  --registry-server "$acrName.azurecr.io" `
  --registry-username $acrUsername `
  --registry-password $acrPassword `
  --target-port 80 `
  --ingress external `
  --env-vars "VITE_API_URL=https://$backendUrl" "VITE_PYTHON_SERVICE_URL=https://$pythonServiceUrl" "VITE_ENABLE_SCREEN_SHARING=true" "VITE_ENABLE_SPEECH_RECOGNITION=true" "VITE_ENABLE_OCR=true" "VITE_ENABLE_ARABIC=true" `
    "VITE_OPENAI_API_KEY=$openaiApiKey" "VITE_GOOGLE_GENERATIVE_AI_API_KEY=$googleGenerativeAiApiKey" "VITE_ELEVENLABS_API_KEY=$elevenlabsApiKey"

# Get Frontend URL
$frontendUrl = az containerapp show `
  --name frontend `
  --resource-group $resourceGroup `
  --query "properties.configuration.ingress.fqdn" -o tsv

Write-Host "Frontend URL: $frontendUrl"

# Configure Auto-scaling
Write-Host "Configuring Auto-scaling..."

az containerapp update `
  --name python-service `
  --resource-group $resourceGroup `
  --min-replicas 1 `
  --max-replicas 3 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 50

az containerapp update `
  --name backend `
  --resource-group $resourceGroup `
  --min-replicas 1 `
  --max-replicas 5 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 50

az containerapp update `
  --name frontend `
  --resource-group $resourceGroup `
  --min-replicas 1 `
  --max-replicas 3 `
  --scale-rule-name http-scale `
  --scale-rule-http-concurrency 50

# Display deployment information
Write-Host "======================================================"
Write-Host "      My Smart Teacher Deployment Information      "
Write-Host "======================================================"
Write-Host ""
Write-Host "Application successfully deployed to Azure Container Apps!"
Write-Host ""
Write-Host "Access URLs:"
Write-Host "- Frontend: https://$frontendUrl"
Write-Host "- Backend: https://$backendUrl"
Write-Host "- Python Service: https://$pythonServiceUrl"
Write-Host ""
Write-Host "Deployment completed!"
