param tags object
param sqlActiveDirectoryAdminLogin string
param sqlActiveDirectoryAdminSID string
param resourceLocation string
param sequence string

var regionAcronym = (resourceLocation=~'australiaeast') ? 'ae' : 'ase'
var commonName=toLower('${tags.Project}-${tags.Environment}-${regionAcronym}-${sequence}')

// resource names
// based on naming standard <resource>-<project>-<environment>-<region>-<seq#>
var sqlServerName = toLower('sqldb-${commonName}')

module m_randompwd 'modules/generateRandomPassword.bicep' = {
  name: 'randomPassword'
  params: {
    resourceLocation: resourceLocation
  }
}

module m_deployAzureSQLDatabase 'modules/AzureSQLDatabase.bicep' = {
  name: 'deployAzureSQLDatabase'
  params: {
    tags: tags    
    resourceLocation: resourceLocation
    sqlServerName: sqlServerName
    sqlDatabaseName: 'mydb'
    sqlActiveDirectoryAdminLogin: sqlActiveDirectoryAdminLogin
    sqlActiveDirectoryAdminSID: sqlActiveDirectoryAdminSID
    sqlDatabaseSkuName: 'Basic'
    sqlDatabaseCapacity: 5
    sqlDatabaseSizeGB: 2 
    sqlAdminLogin: 'sqlAdminLogin'
    sqlAdminLoginPassword: m_randompwd.outputs.secretText
  }
}

