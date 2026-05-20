targetScope = 'subscription'

param workspaceResourceId string

// Enable every CWPP plan at Standard tier with the highest sub-plan when relevant.
// Plan names are the canonical values used by Microsoft.Security/pricings.
var plans = [
  { name: 'VirtualMachines',                  subPlan: 'P2' }
  { name: 'Containers',                       subPlan: '' }
  { name: 'StorageAccounts',                  subPlan: 'DefenderForStorageV2' }
  { name: 'SqlServers',                       subPlan: '' }
  { name: 'SqlServerVirtualMachines',         subPlan: '' }
  { name: 'AppServices',                      subPlan: '' }
  { name: 'KeyVaults',                        subPlan: 'PerKeyVault' }
  { name: 'Arm',                              subPlan: 'PerSubscription' }
  { name: 'Dns',                              subPlan: '' }
  { name: 'OpenSourceRelationalDatabases',    subPlan: '' }
  { name: 'CosmosDbs',                        subPlan: '' }
  { name: 'Api',                              subPlan: 'P1' }
  { name: 'AI',                               subPlan: '' }
]

@batchSize(1)
resource pricing 'Microsoft.Security/pricings@2024-01-01' = [for p in plans: {
  name: p.name
  properties: {
    pricingTier: 'Standard'
    subPlan: empty(p.subPlan) ? null : p.subPlan
  }
}]

// Default workspace setting for VM agents
resource workspaceSetting 'Microsoft.Security/workspaceSettings@2017-08-01-preview' = {
  name: 'default'
  properties: {
    workspaceId: workspaceResourceId
    scope: subscription().id
  }
}

// Auto-provisioning ON for MMA / AMA where applicable
resource autoProv 'Microsoft.Security/autoProvisioningSettings@2017-08-01-preview' = {
  name: 'default'
  properties: { autoProvision: 'On' }
}
