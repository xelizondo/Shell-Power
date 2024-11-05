targetScope = 'tenant'

@description('The name of the diagnostic setting.')
param settingName string = 'sentToEventHub'

@description('The resource Id for the event hub authorization rule.')
param eventHubAuthorizationRuleId string = '/subscriptions/[xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx]/resourceGroups/[ResourceGroup]/providers/Microsoft.EventHub/namespaces/[eventhubnamespace]/authorizationrules/RootManageSharedAccessKey'

@description('The name of the event hub.')
param eventHubName string = 'logs'

resource setting 'microsoft.aadiam/diagnosticSettings@2017-04-01' = {
  name: settingName
  properties: {
    eventHubAuthorizationRuleId: eventHubAuthorizationRuleId
    eventHubName: eventHubName
    logs: [
      {
        enabled: true
        category: 'AuditLogs'
      }
      {
        enabled: true
        category: 'SignInLogs'
      }
      {
        enabled: true
        category: 'NonInteractiveUserSignInLogs'
      }
      {
        enabled: true
        category: 'ServicePrincipalSignInLogs'
      }
      {
        enabled: true
        category: 'ManagedIdentitySignInLogs'
      }
      {
        enabled: true
        category: 'ProvisioningLogs'
      }
      {
        enabled: true
        category: 'ADFSSignInLogs'
      }
      {
        enabled: true
        category: 'RiskyUsers'
      }
      {
        enabled: true
        category: 'UserRiskEvents'
      }
      {
        enabled: true
        category: 'NetworkAccessTrafficLogs'
      }
      {
        enabled: true
        category: 'RiskyServicePrincipals'
      }
      {
        enabled: true
        category: 'ServicePrincipalRiskEvents'
      }
      {
        enabled: true
        category: 'EnrichedOffice365AuditLogs'
      }
      {
        enabled: true
        category: 'MicrosoftGraphActivityLogs'
      }
      {
        enabled: true
        category: 'RemoteNetworkHealthLogs'
      }
    ]
  }
}
