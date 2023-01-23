param storageAccountName string
param resourceLocation string = resourceGroup().location

@description('The type of the Storage Account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RA-GRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_GRS'
  'Premium_RA-GRS'
  'Premium_ZRS'
])
param storageAccountType string = 'Standard_LRS'

//@description('The SKU tier of the Storage Account')
//@allowed([
//  'standard'
//  'premium'
//])
//param storageAccountTier string = 'standard'

@description('The Access tier of the Storage Account')
@allowed([
  'Hot'
  'Cool'
])
param storageAccountAccessTier string = 'Hot'
param storageAccountDataLake bool = true
param tags object

var lifecycleName = 'lcycle-${storageAccountName}'

resource r_storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  tags: tags
  location: resourceLocation
  kind: 'StorageV2'
  sku: {
    name: storageAccountType
  }
  properties: {
    isHnsEnabled: storageAccountDataLake
    accessTier: storageAccountAccessTier
  }
}

resource r_symbolicname 'Microsoft.Storage/storageAccounts/managementPolicies@2022-05-01' = {
  name: 'default'
  parent: r_storageAccount
  properties: {
    policy: {
      rules: [
        {
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 15
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
            }
          }
          enabled: true
          name: lifecycleName
          type: 'Lifecycle'
        }
      ]
    }
  }
}

output storageAccountName string = r_storageAccount.name
