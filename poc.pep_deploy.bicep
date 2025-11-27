param functionAppName string = 'poc-refinity-invoicing-func'
param appServicePlanId string = 'ASP-CAFunctionAppFlexPOC-bb59'
param location string = 'canadacentral'
param outboundSubnetId string = '/subscriptions/${subscriptionId}/resourceGroups/${vnetresourceGroupName}/providers/Microsoft.Network/virtualNetworks/CA-Application/subnets/Dev-FunctionApp-Flex-Outbound'
param subscriptionId string = '883433d1-c6a4-4cd3-9d39-567702e61f18'
param resourceGroupName string = 'CA-FunctionApp-Flex-POC'
param vnetresourceGroupName string = 'CCI-Global-Network'



resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/883433d1-c6a4-4cd3-9d39-567702e61f18/resourcegroups/CA-FunctionApp-Flex-POC/providers/Microsoft.ManagedIdentity/userAssignedIdentities/poc-akzo-invoicing-mi': {}
    }
  }
  properties: {
    httpsOnly: true // Enforce HTTPS
    publicNetworkAccess: 'Disabled' // Disable public access
    serverFarmId: appServicePlanId
    virtualNetworkSubnetId: outboundSubnetId // Outbound VNet integration
    siteConfig: {
      numberOfWorkers: 1
      alwaysOn: false
      functionAppScaleLimit: 100
      minimumElasticInstanceCount: 0
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobcontainer'
          value: 'https://cafunctionappflexpoa5cb.blob.core.windows.net/app-package-poc-refinity-invoicing-func-78b79df'
          authentication: {
            type: 'storageaccountconnectionstring'
            storageAccountConnectionStringName: 'DEPLOYMENT_STORAGE_CONNECTION_STRING'
          }
        }
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '9.0'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
    }
  }
}

// This is the creation of PEP, NIC & the IP Configuration

param privateEndpointName string = 'poc-Refinity-invoicing-PEP'
param functionAppResourceId string = '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Web/sites/${functionAppName}'
param subnetId string = '/subscriptions/${subscriptionId}/resourceGroups/${vnetresourceGroupName}/providers/Microsoft.Network/virtualNetworks/CA-Application/subnets/Dev-FunctionApp-Flex-PEP'
param privateIp string = '10.33.42.50'
param nicName string = 'poc-Refinity-invoicing-NIC'


resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-07-01' = {
  name: privateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: functionAppResourceId // This is where the PEP connects to the Function App 
          groupIds: [
            'sites'
          ]
          privateLinkServiceConnectionState: {
            status: 'Approved'
            actionsRequired: 'None'
          }
        }
      }
    ]
    customNetworkInterfaceName: nicName
    subnet: {
      id: subnetId
    }
    ipConfigurations: [
      {
        name: '${privateEndpointName}-ip'
        properties: {
          memberName: 'sites'
          groupId: 'sites'
          privateIPAddress: privateIp
        }
      }
    ]
  }
}

// This is the creation of Private DNS Zone Group for the PEP

param privateDnsZoneId string = '/subscriptions/${subscriptionId}/resourceGroups/${vnetresourceGroupName}/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net'

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-07-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}


// Managed Private Endpoint from Function App to Fabric Workspace 


param fabricWorkspaceId string = '8fff9aa6-f850-4d58-8279-1809f7369877'
param mpeConnectionName string = '${functionAppName}-Fabric.MPE'


resource fabricMPE 'Microsoft.Web/sites/privateEndpointConnections@2024-11-01' = {
  parent: functionApp
  name: '${fabricWorkspaceId}.${mpeConnectionName}'
  location: location
  properties: {
    privateEndpoint: {}
    privateLinkServiceConnectionState: {
      status: 'Approved'
      actionsRequired: 'None'
    }
  }
}


