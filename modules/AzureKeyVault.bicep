param resourceLocation string = resourceGroup().location
param tags object
param keyVaultName string

@description('The SKU of the Key Vault')
@allowed([
  'standard'
  'premium'
])
param keyVaultSku string = 'standard'
param sqlCredential object
param secretPolicies array

resource r_keyVault 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: resourceLocation
  tags: tags
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    tenantId: subscription().tenantId
    accessPolicies: []
    sku: {
      name: keyVaultSku
      family: 'A'
    }
  }
}

// create secret in KV if param for sql creds is not empty
resource r_secret 'Microsoft.KeyVault/vaults/secrets@2021-06-01-preview' = [for cred in items(sqlCredential): {
  name: cred.value.name
  parent: r_keyVault
  properties: {
    value: cred.value.secret
  }
} ]

// add secret policy - expecting array of secretPolicies that contains object id of the user
resource r_secretPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: 'add'
  parent: r_keyVault
  properties: { 
    accessPolicies: [ for pol in secretPolicies: {
      tenantId: subscription().tenantId
      objectId: pol
      permissions: {
        secrets: [
          'list'
          'get'
          'set'
        ]
      }        
    }]
  }
}

output keyVaultName string = r_keyVault.name
