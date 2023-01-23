param resourceLocation string = resourceGroup().location

resource r_pwd 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'password-generate'
  location: resourceLocation
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '3.0' 
    retentionInterval: 'P1D'
    scriptContent: loadTextContent('../scripts/generateRandomPassword.ps1')
  }
}

output encodedSecret string =  r_pwd.properties.outputs.encodedSecret
output secretText string =  r_pwd.properties.outputs.secret
