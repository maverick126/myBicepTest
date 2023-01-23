param storageAccount string 
param location string = resourceGroup().location

resource thestorage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccount
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind:  'StorageV2'
}
