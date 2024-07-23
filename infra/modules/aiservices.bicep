param location string
param aiServicesName string
param tags object = {}
param privateEndpointSubnetId string
param publicNetworkAccess string
param openAIPrivateDnsZoneId string
param cognitiveServicesPrivateDnsZoneId string


resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: aiServicesName
  location: location
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  properties: {
    disableLocalAuth: true
    customSubDomainName: aiServicesName
    publicNetworkAccess: publicNetworkAccess
  }
  tags: tags
}

resource aiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pl-oai-${aiServicesName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'private-endpoint-connection'
        properties: {
          privateLinkServiceId: aiServices.id
          groupIds: [ 'account' ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'zg-${aiServicesName}'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'default'
          properties: {
            privateDnsZoneId: openAIPrivateDnsZoneId
          }
        }
      ]
    }
  }
}


resource cognitiveServicesPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pl-${aiServicesName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'private-endpoint-connection'
        properties: {
          privateLinkServiceId: aiServices.id
          groupIds: [ 'account' ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'default'
          properties: {
            privateDnsZoneId: cognitiveServicesPrivateDnsZoneId
          }
        }
      ]
    }
  }
}

output aiServicesID string = aiServices.id
output aiServicesName string = aiServices.name
