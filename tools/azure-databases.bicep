@description('اسم مجموعة الموارد')
param resourceGroupName string = 'my-smart-teacher-rg'

@description('موقع الموارد')
param location string = 'uaenorth'

@description('اسم خادم PostgreSQL')
param postgresServerName string = 'my-smart-teacher-postgres'

@description('اسم المستخدم المسؤول لخادم PostgreSQL')
param postgresAdminUser string = 'mstadmin'

@description('كلمة مرور المستخدم المسؤول لخادم PostgreSQL')
@secure()
param postgresAdminPassword string

@description('اسم قاعدة بيانات PostgreSQL')
param postgresDBName string = 'my_smart_teacher'

@description('اسم حساب Cosmos DB')
param cosmosAccountName string = 'my-smart-teacher-cosmos'

@description('اسم قاعدة بيانات Cosmos DB')
param cosmosDBName string = 'my_smart_teacher'

@description('اسم مجموعة Cosmos DB')
param cosmosCollectionName string = 'model_usage_stats'

@description('تمكين الوصول العام للخادم PostgreSQL')
param enablePublicAccess bool = false

// إنشاء خادم PostgreSQL المرن
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgresServerName
  location: location
  sku: {
    name: 'Standard_B1ms'
    tier: 'Burstable'
  }
  properties: {
    version: '14'
    administratorLogin: postgresAdminUser
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: 32
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
    network: {
      publicNetworkAccess: enablePublicAccess ? 'Enabled' : 'Disabled'
    }
  }
}

// إنشاء قاعدة بيانات PostgreSQL
resource postgresDB 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgresServer
  name: postgresDBName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// إنشاء قاعدة جدار الحماية للسماح بالوصول من خدمات Azure
resource firewallRuleAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = if (enablePublicAccess) {
  parent: postgresServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// إنشاء حساب Cosmos DB مع واجهة MongoDB
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
  location: location
  kind: 'MongoDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableMongo'
      }
    ]
    apiProperties: {
      serverVersion: '4.2'
    }
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
      }
    }
  }
}

// إنشاء قاعدة بيانات MongoDB
resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: cosmosDBName
  properties: {
    resource: {
      id: cosmosDBName
    }
  }
}

// إنشاء مجموعة MongoDB
resource cosmosCollection 'Microsoft.DocumentDB/databaseAccounts/mongodbDatabases/collections@2023-04-15' = {
  parent: cosmosDB
  name: cosmosCollectionName
  properties: {
    resource: {
      id: cosmosCollectionName
      shardKey: {
        model: 'Hash'
      }
      indexes: [
        {
          key: {
            keys: ['_id']
          }
        },
        {
          key: {
            keys: ['model']
          }
        },
        {
          key: {
            keys: ['date']
          }
        }
      ]
    }
    options: {
      throughput: 400
    }
  }
}

// إخراج معلومات الاتصال
output postgresServerFQDN string = postgresServer.properties.fullyQualifiedDomainName
output postgresConnectionString string = 'postgres://${postgresAdminUser}:${postgresAdminPassword}@${postgresServer.properties.fullyQualifiedDomainName}:5432/${postgresDBName}'
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output cosmosPrimaryKey string = listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey
output cosmosConnectionString string = 'mongodb://${cosmosAccountName}:${listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey}@${cosmosAccountName}.mongo.cosmos.azure.com:10255/${cosmosDBName}?ssl=true&replicaSet=globaldb&retrywrites=false&maxIdleTimeMS=120000&appName=@${cosmosAccountName}@'
