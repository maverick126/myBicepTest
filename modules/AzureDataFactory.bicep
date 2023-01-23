param adfName string 
param resourceLocation string = resourceGroup().location
param tags object

resource r_dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: adfName
  location: resourceLocation
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }  
}

output dataFactoryName string = r_dataFactory.name
output adfManagedIdentity  string = r_dataFactory.identity.principalId
