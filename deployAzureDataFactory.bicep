param sequence string

module m_deployAzureDataFactory 'modules/AzureDataFactory.bicep' = {
  name: 'deployAzureDataFactory'
  params: {
    sequence: sequence
  }
}
