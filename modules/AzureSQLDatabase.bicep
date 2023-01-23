param tags object
param resourceLocation string = resourceGroup().location

param sqlServerName string
param sqlDatabaseName string 
param sqlActiveDirectoryAdminLogin string
param sqlActiveDirectoryAdminSID string
param sqlAdminLogin string
param sqlDatabaseSkuName string = 'Basic'
param sqlDatabaseCapacity int = 5
param sqlDatabaseSizeGB int = 2 

@secure()
param sqlAdminLoginPassword string

var tenantId = subscription().tenantId
var sqlCollation = 'SQL_Latin1_General_CP1_CI_AS'

resource r_sqlServer 'Microsoft.Sql/servers@2021-08-01-preview' = {
  name: sqlServerName
  location: resourceLocation
  identity: {
    type: 'SystemAssigned'
  }  
  properties: {
    administratorLogin: sqlAdminLogin
    administratorLoginPassword: sqlAdminLoginPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
  }
  tags: tags
}
resource r_sqlDatabase_ADAdmin 'Microsoft.Sql/servers/administrators@2022-02-01-preview' = {
  parent: r_sqlServer
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: sqlActiveDirectoryAdminLogin
    sid: sqlActiveDirectoryAdminSID
    tenantId: tenantId
  }
}

resource r_sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01-preview' = {
  parent: r_sqlServer
  name: sqlDatabaseName
  location: resourceLocation
  sku: {
    name: sqlDatabaseSkuName
    tier: sqlDatabaseSkuName
    capacity: sqlDatabaseCapacity
  }
  tags: tags
  properties: {
    collation: sqlCollation
    maxSizeBytes: (1073741824 * sqlDatabaseSizeGB)
    catalogCollation: sqlCollation
    zoneRedundant: false
    readScale: 'Disabled'
    requestedBackupStorageRedundancy: 'Local'
    isLedgerOn: false
  }
}

resource r_sqlDatabase_default 'Microsoft.Sql/servers/databases/backupLongTermRetentionPolicies@2021-11-01-preview' = {
  parent: r_sqlDatabase
  name: 'default'
  properties: {
    weeklyRetention: 'PT0S'
    monthlyRetention: 'PT0S'
    yearlyRetention: 'PT0S'
    weekOfYear: 1
  }
}

resource r_backupShortTermRetentionPolicies_sqlDatabase 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2021-11-01-preview' = {
  parent: r_sqlDatabase
  name: 'default'
  properties: {
    retentionDays: 7
    diffBackupIntervalInHours: 24
  }
}

// enable auditing at server level
resource r_sqlAuditing 'Microsoft.Sql/servers/auditingSettings@2022-05-01-preview' = {
  parent: r_sqlServer
  name: 'default'
  properties: {
    isDevopsAuditEnabled: false
    retentionDays: 0
    isAzureMonitorTargetEnabled: true
    isManagedIdentityInUse: false
    state: 'Enabled'
    auditActionsAndGroups: [
      'SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP'
      'FAILED_DATABASE_AUTHENTICATION_GROUP'
      'BATCH_COMPLETED_GROUP'
    ]  
  }

}

// var sqlPrivEndpointName = 'pe-${sqlServerName}'
// resource r_sqlServerPrivateEndpoint 'Microsoft.Sql/servers/privateEndpointConnections@2022-05-01-preview' = {
//   parent: r_sqlServer
//   name: sqlPrivEndpointName
//   properties:{
//     privateEndpoint: {
//       id: sqlPrivEndpointName
//     }
//     privateLinkServiceConnectionState: {
//       status: 'Approved'
//       description: 'Auto-approved'
//     }
//   }
// }

// resource r_sqlServerFirewallAllowAzure 'Microsoft.Sql/servers/firewallRules@2021-11-01-preview' = {
//   parent: r_sqlServer
//   name: 'AllowAllWindowsAzureIps'
//   properties:{
//     startIpAddress: '0.0.0.0'
//     endIpAddress: '0.0.0.0'
//   }
// }

// resource r_sqlDatabase_Current 'Microsoft.Sql/servers/databases/transparentDataEncryption@2021-11-01-preview' = {
//   parent: r_sqlDatabase
//   name: 'Current'
//   properties: {
//     state: 'Enabled'
//   }
// }

output sqldbID string = r_sqlServer.id
output sqlServerName string = r_sqlServer.name
output sqlManagedIdentity  string = r_sqlServer.identity.principalId
