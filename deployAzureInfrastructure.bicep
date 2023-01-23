// Common to all resources
param tags object
param resourceLocation string
param sequence string

// KeyVault params
param keyVaultSku string
param secretAccessPolicy array

// Storage account params
param storageAccountType string
param storageAccountDataLake bool
param storageAccountAccessTier string

// SQL Database params
@secure()
param secretPass string

param sqlActiveDirectoryAdminLogin string
param sqlActiveDirectoryAdminSID string
param sqlAdminLogin string
param sqlDatabaseName string

// Log Analytics params
param logAnalyticsSku string

// use this for random password
module m_randompwd 'modules/generateRandomPassword.bicep' = {
  name: 'randomPassword'
  params: {
    resourceLocation: resourceLocation
  }
}
var regionAcronym = (resourceLocation=~'australiaeast') ? 'ae' : 'ase'
var commonName=toLower('${tags.Project}-${tags.Environment}-${regionAcronym}-${sequence}')

// resource names
// based on naming standard <resource>-<project>-<environment>-<region>-<seq#>
var keyVaultName = toLower('kv-${commonName}')
var sqlServerName = toLower('sqldb-${commonName}')
var adfName = toLower('adf-${commonName}')
var logAnalyticsWorkspaceName = toLower('la-${commonName}')
var automationAccountName = toLower('aa-${commonName}')
var storageAccountName = toLower('sto${tags.Project}${tags.Environment}${regionAcronym}${sequence}')


// credentials to create as secrets in keyvault
var sqlCreds = { 
    secretName: {
      name: 'sqladminUser'
      secret: sqlAdminLogin
    }
    secretText: {
      name: 'sqladminUserSecret'
      secret: m_randompwd.outputs.secretText
    }    
}

///////////////////////////////////////////////
// Build Azure resources

// Key Vault
module m_keyVault 'modules/AzureKeyVault.bicep' = {
  name: 'deployAzureKeyVault'
  params: {
    tags: tags
    resourceLocation: resourceLocation
    keyVaultName: keyVaultName
    keyVaultSku: keyVaultSku
    sqlCredential: sqlCreds
    secretPolicies: secretAccessPolicy
  }
}

// Log Analytics
module m_logAnalyticsWorkspace 'modules/AzureLogAnalytics.bicep' = {
  name: 'deployAzureLogAnalytics'
  params: {
    tags: tags    
    resourceLocation: resourceLocation   
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    logAnalyticsSku: logAnalyticsSku
  }
}

// Storage Account / Data Lake
module m_storageAccount 'modules/AzureStorageAccount.bicep' = {
  name: 'deployAzureStorageAccount'
  params: {
    tags: tags
    resourceLocation: resourceLocation
    storageAccountName: storageAccountName
    storageAccountType: storageAccountType
    storageAccountDataLake: storageAccountDataLake 
    storageAccountAccessTier: storageAccountAccessTier     
  }
}

// Azure SQL Database
module m_deployAzureSQLDatabase 'modules/AzureSQLDatabase.bicep' = {
  name: 'deployAzureSQLDatabase'
  params: {
    tags: tags    
    resourceLocation: resourceLocation
    sqlServerName: sqlServerName    
    sqlDatabaseName: sqlDatabaseName
    sqlActiveDirectoryAdminLogin: sqlActiveDirectoryAdminLogin
    sqlActiveDirectoryAdminSID: sqlActiveDirectoryAdminSID
    sqlDatabaseSkuName: 'Basic'
    sqlDatabaseCapacity: 5
    sqlDatabaseSizeGB: 2 
    sqlAdminLogin: sqlAdminLogin
    sqlAdminLoginPassword: m_randompwd.outputs.secretText
  }
  dependsOn: [
    m_logAnalyticsWorkspace
  ]
}

// Data Factory
module m_dataFactory 'modules/AzureDataFactory.bicep' = {
  name: 'deployAzureDataFactory'
  params: {
    tags: tags
    resourceLocation: resourceLocation
    adfName: adfName    
  }
  dependsOn: [
    m_logAnalyticsWorkspace
  ]
}

// Automation Account
module m_automationAccount 'modules/AzureAutomationAccount.bicep' = {
  name: 'deployAzureAutomationAccount'
  params: {
    tags: tags
    resourceLocation: resourceLocation
    automationAccountName: automationAccountName        
  }
}

///////////////////////////////////////////////
// Optional resource configurations 

// add adf system managed id acces policy to Keyvault
resource adfSecretPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' =  {
  name: any('${keyVaultName}/add')
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: m_dataFactory.outputs.adfManagedIdentity
        permissions: {
          secrets: [
            'list'
            'get'
          ]
        }       
      }
    ]
  }
}

//
// SQL Auditing going to loganalytics
var sqlAuditName = 'SQLAuditing[${logAnalyticsWorkspaceName}]'
resource r_sqlauditing 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: sqlAuditName
  location: resourceLocation
  tags: tags
  plan: {
    name: sqlAuditName
    product: 'SQLAuditing'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: m_logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
    containedResources: [
      '${m_logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId}/views/SQLSecurityInsights'
      '${m_logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId}/views/SQLAccessToSensitiveData'
    ]
  }
  dependsOn:[
    m_deployAzureSQLDatabase
    m_logAnalyticsWorkspace
  ]
}

//
// SQL Auditing diagnostics enable to use loganalytics
resource r_sqlServerScope  'Microsoft.Sql/servers@2021-08-01-preview' existing = {
  name: sqlServerName
}
resource r_masterDB 'Microsoft.Sql/servers/databases@2022-05-01-preview' existing = {
  parent: r_sqlServerScope
  name: 'master'
}
resource r_sqlDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${sqlServerName}'
  scope: r_masterDB
  properties: {
    workspaceId: m_logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
  dependsOn: [
    m_deployAzureSQLDatabase
    m_logAnalyticsWorkspace
  ]
}

//
// ADF diagnostics
resource r_adfScope  'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: adfName
}
resource r_adfDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${adfName}'
  scope: r_adfScope
  properties: {
    workspaceId: m_logAnalyticsWorkspace.outputs.logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      {
        category: 'PipelineRuns'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'TriggerRuns'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        category: 'ActivityRuns'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }            
    ]
  }
  dependsOn: [
    m_dataFactory
    m_logAnalyticsWorkspace
  ]
}


output factoryName string = m_dataFactory.outputs.dataFactoryName
output keyvaultName string = m_keyVault.outputs.keyVaultName
output storageName string = m_storageAccount.outputs.storageAccountName
output sqlServerName string = m_deployAzureSQLDatabase.outputs.sqlServerName
// output randomSecret string = m_randompwd.outputs.secretText
