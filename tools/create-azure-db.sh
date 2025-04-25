#!/bin/bash
# سكريبت لإنشاء قواعد البيانات على Azure

# المعلمات
RESOURCE_GROUP="my-smart-teacher-rg"
LOCATION="uaenorth"
POSTGRES_SERVER_NAME="my-smart-teacher-pg"
POSTGRES_ADMIN_USER="mstadmin"
POSTGRES_DB_NAME="my_smart_teacher"
COSMOS_ACCOUNT_NAME="my-smart-teacher-cosmos"
COSMOS_DB_NAME="my_smart_teacher"
COSMOS_COLLECTION_NAME="model_usage_stats"
ENABLE_PUBLIC_ACCESS=false

# طلب كلمة المرور
echo "أدخل كلمة مرور مشرف PostgreSQL:"
read -s POSTGRES_ADMIN_PASSWORD

# التحقق من تسجيل الدخول إلى Azure
echo "التحقق من تسجيل الدخول إلى Azure..."
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "لم يتم تسجيل الدخول إلى Azure. الرجاء تسجيل الدخول أولاً."
    az login
else
    ACCOUNT=$(az account show --query user.name -o tsv)
    echo "تم تسجيل الدخول كـ: $ACCOUNT"
fi

# التحقق من وجود مجموعة الموارد
echo "التحقق من وجود مجموعة الموارد..."
EXISTS=$(az group exists --name "$RESOURCE_GROUP")
if [ "$EXISTS" == "true" ]; then
    echo "مجموعة الموارد '$RESOURCE_GROUP' موجودة بالفعل."
else
    echo "إنشاء مجموعة الموارد '$RESOURCE_GROUP' في الموقع '$LOCATION'..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
fi

# إنشاء خادم PostgreSQL
echo -e "\n===== إنشاء قاعدة بيانات PostgreSQL ====="
SERVER_EXISTS=$(az postgres flexible-server show --name "$POSTGRES_SERVER_NAME" --resource-group "$RESOURCE_GROUP" 2>/dev/null)
if [ -n "$SERVER_EXISTS" ]; then
    echo "خادم PostgreSQL '$POSTGRES_SERVER_NAME' موجود بالفعل."
else
    echo "إنشاء خادم PostgreSQL '$POSTGRES_SERVER_NAME'..."
    
    # إنشاء خادم PostgreSQL المرن
    az postgres flexible-server create \
        --name "$POSTGRES_SERVER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --admin-user "$POSTGRES_ADMIN_USER" \
        --admin-password "$POSTGRES_ADMIN_PASSWORD" \
        --sku-name Standard_B1ms \
        --tier Burstable \
        --storage-size 32 \
        --version 14 \
        --high-availability Disabled \
        --public-access "$ENABLE_PUBLIC_ACCESS"
    
    if [ $? -ne 0 ]; then
        echo "فشل في إنشاء خادم PostgreSQL."
        exit 1
    fi
fi

# إنشاء قاعدة البيانات PostgreSQL
echo "إنشاء قاعدة بيانات PostgreSQL '$POSTGRES_DB_NAME'..."
az postgres flexible-server db create \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$POSTGRES_SERVER_NAME" \
    --database-name "$POSTGRES_DB_NAME"

# إضافة قواعد جدار الحماية إذا تم تمكين الوصول العام
if [ "$ENABLE_PUBLIC_ACCESS" == "true" ]; then
    echo "إضافة قاعدة جدار الحماية للسماح بالوصول من خدمات Azure..."
    az postgres flexible-server firewall-rule create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$POSTGRES_SERVER_NAME" \
        --rule-name AllowAzureServices \
        --start-ip-address 0.0.0.0 \
        --end-ip-address 0.0.0.0
fi

# إنشاء حساب Cosmos DB
echo -e "\n===== إنشاء قاعدة بيانات Cosmos DB (MongoDB) ====="
ACCOUNT_EXISTS=$(az cosmosdb check-name-exists --name "$COSMOS_ACCOUNT_NAME")
if [ "$ACCOUNT_EXISTS" == "true" ]; then
    echo "حساب Cosmos DB '$COSMOS_ACCOUNT_NAME' موجود بالفعل."
else
    echo "إنشاء حساب Cosmos DB '$COSMOS_ACCOUNT_NAME' مع واجهة MongoDB API..."
    
    # إنشاء حساب Cosmos DB مع واجهة MongoDB
    az cosmosdb create \
        --name "$COSMOS_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --kind MongoDB \
        --capabilities EnableMongo \
        --default-consistency-level Session \
        --locations regionName="$LOCATION" failoverPriority=0 isZoneRedundant=False
    
    if [ $? -ne 0 ]; then
        echo "فشل في إنشاء حساب Cosmos DB."
        exit 1
    fi
fi

# إنشاء قاعدة بيانات MongoDB
echo "إنشاء قاعدة بيانات MongoDB '$COSMOS_DB_NAME'..."
az cosmosdb mongodb database create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --name "$COSMOS_DB_NAME"

# إنشاء مجموعة MongoDB
echo "إنشاء مجموعة MongoDB '$COSMOS_COLLECTION_NAME'..."
az cosmosdb mongodb collection create \
    --account-name "$COSMOS_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --database-name "$COSMOS_DB_NAME" \
    --name "$COSMOS_COLLECTION_NAME" \
    --shard "model" \
    --throughput 400

# الحصول على معلومات الاتصال
echo -e "\n===== الحصول على معلومات الاتصال ====="

# معلومات PostgreSQL
POSTGRES_FQDN="$POSTGRES_SERVER_NAME.postgres.database.azure.com"
POSTGRES_CONNECTION_STRING="postgres://$POSTGRES_ADMIN_USER:$POSTGRES_ADMIN_PASSWORD@$POSTGRES_FQDN:5432/$POSTGRES_DB_NAME"

# معلومات Cosmos DB
COSMOS_KEYS=$(az cosmosdb keys list --name "$COSMOS_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP")
COSMOS_PRIMARY_KEY=$(echo $COSMOS_KEYS | jq -r '.primaryMasterKey')
COSMOS_CONNECTION_STRING="mongodb://$COSMOS_ACCOUNT_NAME:$COSMOS_PRIMARY_KEY@$COSMOS_ACCOUNT_NAME.mongo.cosmos.azure.com:10255/$COSMOS_DB_NAME?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@$COSMOS_ACCOUNT_NAME@"

# إنشاء ملف .env
cat > .env.azure << EOL
# متغيرات قاعدة بيانات PostgreSQL
DB_HOST=$POSTGRES_FQDN
DB_PORT=5432
DB_USER=$POSTGRES_ADMIN_USER
DB_PASSWORD=$POSTGRES_ADMIN_PASSWORD
DB_NAME=$POSTGRES_DB_NAME
DATABASE_URL=$POSTGRES_CONNECTION_STRING

# متغيرات قاعدة بيانات MongoDB
MONGO_URI=$COSMOS_CONNECTION_STRING
MONGODB_URI=$COSMOS_CONNECTION_STRING

# متغيرات بيئة التطبيق
NODE_ENV=production
PORT=3001
JWT_SECRET=your_jwt_secret_here
ENABLE_AI_FEATURES=true
ENABLE_FALLBACK=true
MAX_DAILY_TOKENS=100000
MAX_MONTHLY_TOKENS=3000000

# متغيرات مفاتيح API للذكاء الاصطناعي
OPENAI_API_KEY=your_openai_api_key_here
GOOGLE_AI_API_KEY=your_google_ai_api_key_here
GROQ_API_KEY=your_groq_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# متغيرات الأمان
CRYPTO_SECRET_KEY=your_crypto_secret_key_here
CRYPTO_IV=your_crypto_iv_here
EOL

echo "تم إنشاء ملف .env.azure في المسار الحالي"

# عرض معلومات الاتصال
echo -e "\n===== معلومات الاتصال بقواعد البيانات ====="
echo "PostgreSQL Connection String: $POSTGRES_CONNECTION_STRING"
echo "MongoDB Connection String: $COSMOS_CONNECTION_STRING"

echo -e "\n✅ تم إنشاء قواعد البيانات بنجاح!"
echo "يمكنك استخدام ملف .env.azure لتكوين تطبيقك للاتصال بقواعد البيانات."

# إرشادات إضافية
echo -e "\n===== الخطوات التالية ====="
echo "1. انسخ ملف .env.azure إلى دليل التطبيق الخلفي"
echo "2. قم بتحديث متغيرات البيئة في تطبيق Container App الخاص بك"
echo "3. قم بتشغيل الترحيلات لإنشاء الجداول في قاعدة البيانات PostgreSQL"

# إظهار معلومات عن المستودعات والخدمات
echo -e "\n===== المستودعات والخدمات المدعومة ====="
echo "المستودعات:"
echo "- ModelFallbackLogRepository: يتعامل مع سجلات تبديل النماذج"
echo "- AiModelConfigRepository: يدير إعدادات نماذج الذكاء الاصطناعي"
echo "- PromptTemplateRepository: يدير قوالب البرومبت"
echo "- PromptLibraryImportRepository: يتعامل مع سجلات استيراد مكتبة البرومبت"
echo "- ModelUsageStatsRepository: يدير إحصائيات استخدام النماذج في MongoDB"
echo "- AiTeacherRepository: يدير المعلمين الذكيين"

echo -e "\nالخدمات:"
echo "- ApiKeyService: خدمة شاملة لإدارة مفاتيح API"
echo "- CryptoService: خدمة للتشفير وفك التشفير"
echo "- SystemSettingService: خدمة لإدارة إعدادات النظام"
echo "- AiModelConfigService: خدمة لإدارة إعدادات نماذج الذكاء الاصطناعي"
echo "- PromptTemplateService: خدمة لإدارة قوالب البرومبت"
echo "- ModelUsageStatsService: خدمة لإدارة وتحليل إحصائيات استخدام النماذج"
