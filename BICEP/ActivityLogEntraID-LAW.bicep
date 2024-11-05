targetScope = 'tenant'

param lawResourceId string = '/subscriptions/<SUB ID>/resourceGroups/<RSG NAME>/providers/Microsoft.OperationalInsights/workspaces/<LAW NAME>'

resource aadLogs 'microsoft.aadiam/diagnosticSettings@2017-04-01' = {
  name: 'sentToLAW'
  properties: {
    workspaceId: lawResourceId
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
