param location string = resourceGroup().location
param vmSize string = 'Standard_D2s_v3'
param adminUsername string = 'adminUser'
param storageAccountName string = 'carlostransitfiles'
param dns_suffix string = 'jv7iuxewgz5zw'

param kafkaVmNamePrefix string = 'kafka-vm'
param zookeeperVmNamePrefix string = 'zk-vm'
param kafkaVersion string = '3.3.2'

param azureStorageAccountTopics string = 'azure-storage-account-topic-1'

@secure()
param adminPassword string

var configStorageAccountUrl = 'https://${storageAccountName}.blob.${environment().suffixes.storage}'
var kafkaBlobUri = '${configStorageAccountUrl}/sharefiles/install-kafka-and-connect.sh'
var zookeeperBlobUri = '${configStorageAccountUrl}/sharefiles/install-zookeeper.sh'

var kafkaBootstrapServersArray = [for i in range(0, 3): '${kafkaVmNamePrefix}${i}-${dns_suffix}.${location}.cloudapp.azure.com:9092']
var kafkaBootstrapServers = join(kafkaBootstrapServersArray, ',')

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'kafkaVNet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

// Network Security Group
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'kafkaNSG'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowKafka'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '9092'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowZooKeeper'
        properties: {
          priority: 1200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '2181'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowKafkaConnect'
        properties: {
          priority: 1300
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '8083'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// Public IP Address for ZooKeeper
resource zookeeperPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${zookeeperVmNamePrefix}-publicIP'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${zookeeperVmNamePrefix}-${dns_suffix}')
    }
  }
}

// Network Interface for ZooKeeper
resource zookeeperNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${zookeeperVmNamePrefix}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: zookeeperPublicIp.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// ZooKeeper VM
resource zookeeperVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: '${zookeeperVmNamePrefix}0'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${zookeeperVmNamePrefix}0'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: zookeeperNic.id
        }
      ]
    }
  }
}

// ZooKeeper VM Extension
resource zookeeperExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: zookeeperVm
  name: 'zookeeperExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        zookeeperBlobUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'sh install-zookeeper.sh'
    }
  }
}

// Public IP Addresses for Kafka
resource kafkaPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = [for i in range(0, 3): {
  name: '${kafkaVmNamePrefix}-publicIP${i}'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${kafkaVmNamePrefix}${i}-${dns_suffix}')
    }
  }
}]

// Network Interfaces for Kafka
resource kafkaNic 'Microsoft.Network/networkInterfaces@2023-11-01' = [for i in range(0, 3): {
  name: '${kafkaVmNamePrefix}-nic${i}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: kafkaPublicIp[i].id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}]

// Kafka VMs
resource kafkaVm 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, 3): {
  name: '${kafkaVmNamePrefix}${i}'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${kafkaVmNamePrefix}${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: kafkaNic[i].id
        }
      ]
    }
  }
  dependsOn: [
    zookeeperVm
  ]
}]

// Kafka VM Extensions
resource kafkaExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for i in range(0, 3): {
  parent: kafkaVm[i]
  name: 'kafkaExtension${i}'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        kafkaBlobUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'sh install-kafka-and-connect.sh ${zookeeperPublicIp.properties.dnsSettings.fqdn} ${i} ${kafkaPublicIp[i].properties.dnsSettings.fqdn} ${kafkaVersion} ${kafkaBootstrapServers} ${configStorageAccountUrl} ${newStorageAccount.name} ${newStorageAccountKey} ${newContainer.name} ${azureStorageAccountTopics} ${adminUsername}'
    }
  }
}]

// Create a new storage account for Kafka topic output
resource newStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'kafkatopic${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
  }
}

var newStorageAccountKey = newStorageAccount.listKeys().keys[0].value

resource blobsvc 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: newStorageAccount
  name: 'default'
}

resource newContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: 'output'
  parent: blobsvc
  properties: {
    publicAccess: 'None'
    metadata: {}
  }
}

output zookeeperHostname string = zookeeperPublicIp.properties.dnsSettings.fqdn
output kafkaBootstrapServers string = kafkaBootstrapServers
output kafkaConnectUrls array = [for i in range(0, 3): kafkaPublicIp[i].properties.dnsSettings.fqdn]
output newStorageAccountName string = newStorageAccount.name
output newStorageAccountKey string = newStorageAccountKey
