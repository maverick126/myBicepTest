param resourceLocation string = resourceGroup().location
param tags object
param logAnalyticsWorkspaceName string

@description('The SKU of the Log Analytics')
@allowed([
  'pergb2018'
  'pernode'
  'standalone'
])
param logAnalyticsSku string = 'pergb2018'

resource r_logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  tags: tags
  location: resourceLocation
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 50
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output logAnalyticsWorkspaceName string = r_logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = r_logAnalyticsWorkspace.id
