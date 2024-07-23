param location string
param searchName string
param tags object = {}
param publicNetworkAccess string
param privateEndpointSubnetId string
param privateDnsZoneId string

param storageName string
param aiServicesName string


resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aiServicesName
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: searchName
  location: location
  tags: tags
  sku: {
    name: 'standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    networkRuleSet: {
      bypass: 'AzureServices'
    }
    disableLocalAuth: true
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: publicNetworkAccess
  }
  resource linkToStorage 'sharedPrivateLinkResources' = {
    name: 'link-to-storage-account'
    properties: {
      groupId: 'blob'
      privateLinkResourceId: storage.id
      requestMessage: 'Requested Private Endpoint Connection from Search Service ${searchName}'
    }
  }
  resource linkToAI 'sharedPrivateLinkResources' = {
    name: 'link-to-ai-service'
    properties: {
      groupId: 'openai_account'
      privateLinkResourceId: aiServices.id
      requestMessage: 'Requested Private Endpoint Connection from Search Service ${searchName}'
    }
    dependsOn: [
      linkToStorage
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pl-${searchName}'
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
          privateLinkServiceId: search.id
          groupIds: [ 'searchService' ]
        }
      }
    ]
  }
  resource privateDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'zg-${searchName}'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'default'
          properties: {
            privateDnsZoneId: privateDnsZoneId
          }
        }
      ]
    }
  }
}

output searchID string = search.id
output searchName string = search.name
