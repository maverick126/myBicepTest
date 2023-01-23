param automationAccountName string 
param resourceLocation string = resourceGroup().location
param tags object

resource r_automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountName
  tags: tags
  location: resourceLocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: true
    disableLocalAuth: false
    sku: {
      name: 'Basic'
    }
    encryption: {
      keySource: 'Microsoft.Automation'
      identity: {
      }
    }
  }
}

output automationAccountName string = automationAccountName
