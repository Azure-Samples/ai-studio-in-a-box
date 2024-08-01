targetScope = 'subscription'

// Common configurations
@description('Name of the environment')
param environmentName string
@description('Principal ID to grant access to the AI services')
param myPrincipalId string = ''
@description('Resource group name for the AI services')
param resourceGroupName string = ''
@description('Resource group name for the DNS configurations')
param dnsResourceGroupName string = ''
@description('Tags for all AI resources created')
param tags object

// Network configurations
@allowed(['Enabled', 'Disabled'])
@description('Allow or deny public network access to the AI services (recommended: Disabled)')
param publicNetworkAccess string
@allowed(['identity', 'accessKey'])
@description('Authentication type to use with Storage Account (recommended: identity)')
param systemDatastoresAuthMode string
@description('Address prefixes for the spoke vNet')
param vnetAddressPrefixes array = ['10.0.0.0/16']
@description('Address prefix for the private endpoint subnet')
param privateEndpointSubnetAddressPrefix string = '10.0.0.0/24'
@description('Address prefix for the application subnet')
param appSubnetAddressPrefix string = '10.0.1.0/24'

// AI Services configurations
@description('Name of the AI Services account')
param aiServicesName string = ''
@description('Name of the AI Hub resource')
param aiHubName string = ''
@description('Name of the Storage Account')
param storageName string = ''
@description('Name of the Key Vault')
param keyVaultName string = ''
@description('Whether to deploy Azure AI Search service')
param deploySearch bool
@description('Name of the AI Search Service')
param searchName string = ''
@description('Whether to deploy shared private links from AI Search')
param deploySharedPrivateLinks bool = deploySearch
@description('Whether to deploy a sample AI Project')
param deployAIProject bool = true

var location = deployment().location
var abbrs = loadJsonContent('abbreviations.json')
var uniqueSuffix = substring(uniqueString(subscription().id, environmentName), 1, 3)

var names = {
  resourceGroup: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  dnsResourceGroup: !empty(dnsResourceGroupName) ? dnsResourceGroupName : '${abbrs.resourcesResourceGroups}dns'
  vnet: '${abbrs.networkVirtualNetworks}${environmentName}-${uniqueSuffix}'
  privateLinkSubnet: '${abbrs.networkVirtualNetworksSubnets}${environmentName}-pl-${uniqueSuffix}'
  appSubnet: '${abbrs.networkVirtualNetworksSubnets}${environmentName}-app-${uniqueSuffix}'
  aiServices: !empty(aiServicesName)
    ? aiServicesName
    : '${abbrs.cognitiveServicesAccounts}${environmentName}-${uniqueSuffix}'
  aiHub: !empty(aiHubName) ? aiHubName : '${abbrs.cognitiveServicesAccounts}hub-${environmentName}-${uniqueSuffix}'
  search: !empty(searchName) ? searchName : '${abbrs.searchSearchServices}${environmentName}-${uniqueSuffix}'
  storage: !empty(storageName)
    ? storageName
    : replace(replace('${abbrs.storageStorageAccounts}${environmentName}${uniqueSuffix}', '-', ''), '_', '')
  keyVault: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${environmentName}-${uniqueSuffix}'
  computeInstance: '${abbrs.computeVirtualMachines}${environmentName}-${uniqueSuffix}'
}

// Deploy two resource groups
resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: names.resourceGroup
  location: location
  tags: tags
}

resource dnsResourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: names.dnsResourceGroup
  location: location
}

// Network module - deploys Vnet
module m_network 'modules/network.bicep' = {
  name: 'deploy_vnet'
  scope: resourceGroup
  params: {
    location: location
    vnetName: names.vnet
    vnetAddressPrefixes: vnetAddressPrefixes
    privateEndpointSubnetName: names.privateLinkSubnet
    privateEndpointSubnetAddressPrefix: privateEndpointSubnetAddressPrefix
    appSubnetName: names.appSubnet
    appSubnetAddressPrefix: appSubnetAddressPrefix
  }
}

// DNS module - deploys private DNS zones and links them to the Vnet
module m_dns 'modules/dns.bicep' = {
  name: 'deploy_dns'
  scope: dnsResourceGroup
  params: {
    vnetId: m_network.outputs.vnetId
    vnetName: m_network.outputs.vnetName
    dnsZones: [
      'privatelink.openai.azure.com'
      'privatelink.cognitiveservices.azure.com'
      'privatelink.blob.${environment().suffixes.storage}'
      'privatelink.vault.azure.com'
      'privatelink.search.azure.com'
      'privatelink.documents.azure.com'
      'privatelink.api.azureml.ms'
      'privatelink.notebooks.azure.net'
    ]
  }
}

// AI Services modules - deploy Cognitive Services and AI Search
module m_aiservices 'modules/aiservices.bicep' = {
  name: 'deploy_aiservices'
  scope: resourceGroup
  params: {
    location: location
    aiServicesName: names.aiServices
    publicNetworkAccess: publicNetworkAccess
    privateEndpointSubnetId: m_network.outputs.privateEndpointSubnetId
    openAIPrivateDnsZoneId: m_dns.outputs.dnsZoneIds[0]
    cognitiveServicesPrivateDnsZoneId: m_dns.outputs.dnsZoneIds[1]
    grantAccessTo: [
      {
        id: myPrincipalId
        type: 'User'
      }
      {
        id: deploySearch ? m_search.outputs.searchPrincipalId : ''
        type: 'ServicePrincipal'
      }
    ]
    tags: tags
  }
}

module m_search 'modules/searchService.bicep' = if (deploySearch) {
  name: 'deploy_search'
  scope: resourceGroup
  params: {
    location: location
    searchName: names.search
    publicNetworkAccess: publicNetworkAccess
    privateEndpointSubnetId: m_network.outputs.privateEndpointSubnetId
    privateDnsZoneId: m_dns.outputs.dnsZoneIds[4]
    tags: tags
  }
}

module m_sharedPrivateLinks 'modules/sharedPrivateLinks.bicep' = if (deploySharedPrivateLinks) {
  name: 'deploy_sharedPrivateLinks'
  scope: resourceGroup
  params: {
    searchName: names.search
    openaiName: m_aiservices.outputs.aiServicesName
    storageName: m_storage.outputs.storageName
    grantAccessTo: [
      {
        id: myPrincipalId
        type: 'User'
      }
      {
        id: m_aiservices.outputs.aiservicesPrincipalId
        type: 'ServicePrincipal'
      }
    ]
  }
}

// Storage and Key Vault - AI Hub dependencies
module m_storage 'modules/storage.bicep' = {
  name: 'deploy_storage'
  scope: resourceGroup
  params: {
    location: location
    storageName: names.storage
    publicNetworkAccess: publicNetworkAccess
    systemDatastoresAuthMode: systemDatastoresAuthMode
    privateEndpointSubnetId: m_network.outputs.privateEndpointSubnetId
    privateDnsZoneId: m_dns.outputs.dnsZoneIds[2]
    tags: tags
  }
}

module m_keyVault 'modules/keyVault.bicep' = {
  name: 'deploy_keyVault'
  scope: resourceGroup
  params: {
    location: location
    keyVaultName: names.keyVault
    publicNetworkAccess: publicNetworkAccess
    privateEndpointSubnetId: m_network.outputs.privateEndpointSubnetId
    privateDnsZoneId: m_dns.outputs.dnsZoneIds[3]
    tags: tags
  }
}

// AI Hub module - deploys AI Hub and Project
module m_aihub 'modules/aihub.bicep' = {
  name: 'deploy_ai'
  scope: resourceGroup
  params: {
    location: location
    aiHubName: names.aiHub
    aiProjectName: 'cog-ai-prj-${environmentName}-${uniqueSuffix}'
    aiServicesName: m_aiservices.outputs.aiServicesName
    keyVaultName: m_keyVault.outputs.keyVaultName
    storageName: names.storage
    searchName: deploySearch ? m_search.outputs.searchName : ''
    publicNetworkAccess: publicNetworkAccess
    systemDatastoresAuthMode: systemDatastoresAuthMode
    privateEndpointSubnetId: m_network.outputs.privateEndpointSubnetId
    apiPrivateDnsZoneId: m_dns.outputs.dnsZoneIds[6]
    notebookPrivateDnsZoneId: m_dns.outputs.dnsZoneIds[7]
    defaultComputeName: names.computeInstance
    deployAIProject: deployAIProject
    tags: tags
  }
}

output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP_ID string = resourceGroup.id
output AZURE_RESOURCE_GROUP_NAME string = resourceGroup.name
