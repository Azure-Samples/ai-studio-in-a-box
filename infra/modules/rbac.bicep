param aiServicesName string
param storageName string
param searchName string = ''
param myPrincipalId string

resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: aiServicesName
}
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}
resource search 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: searchName
}

// Search roles
resource searchServiceContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
}

resource searchIndexDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
}

resource aiToSearch1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, aiServices.id, searchServiceContributor.id)
  scope: search
  properties: {
    roleDefinitionId: searchServiceContributor.id
    principalId: aiServices.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource aiToSearch2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, aiServices.id, searchIndexDataContributor.id)
  scope: search
  properties: {
    roleDefinitionId: searchIndexDataContributor.id
    principalId: aiServices.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource meToSearch1 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, myPrincipalId, searchServiceContributor.id)
  scope: search
  properties: {
    roleDefinitionId: searchServiceContributor.id
    principalId: myPrincipalId
    principalType: 'User'
  }
}

resource meToSearch2 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, myPrincipalId, searchIndexDataContributor.id)
  scope: search
  properties: {
    roleDefinitionId: searchIndexDataContributor.id
    principalId: myPrincipalId
    principalType: 'User'
  }
}

// AI roles
resource cognitiveServicesOpenAIContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}

resource searchToAI 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, search.id, cognitiveServicesOpenAIContributor.id)
  scope: aiServices
  properties: {
    roleDefinitionId: cognitiveServicesOpenAIContributor.id
    principalId: search.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource meToAI 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, myPrincipalId, cognitiveServicesOpenAIContributor.id)
  scope: aiServices
  properties: {
    roleDefinitionId: cognitiveServicesOpenAIContributor.id
    principalId: myPrincipalId
    principalType: 'User'
  }
}

// Storage roles
resource storageBlobDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

resource searchToStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(search.id, storage.id, storageBlobDataContributor.id)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributor.id
    principalId: search.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource meToStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, myPrincipalId, cognitiveServicesOpenAIContributor.id)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributor.id
    principalId: myPrincipalId
    principalType: 'User'
  }
}
