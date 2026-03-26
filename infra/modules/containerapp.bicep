// -------------------------------------------------------
// Azure Container Apps Environment + Container App
// -------------------------------------------------------

@description('デプロイ先のリージョン')
param location string

@description('環境名')
param environment string

@description('ワークロード名')
param workloadName string

@description('リソースタグ')
param tags object

@description('ACR ログインサーバー')
param acrLoginServer string

@description('ACR リソース名')
param acrName string

@description('コンテナイメージ (初回はプレースホルダーを使用)')
param containerImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

// Azure CAF 命名規則
var logAnalyticsName = 'log-${workloadName}-${environment}'
var containerAppEnvName = 'cae-${workloadName}-${environment}'
var containerAppName = 'ca-${workloadName}-${environment}'

// -------------------------------------------------------
// Log Analytics Workspace
// -------------------------------------------------------
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// -------------------------------------------------------
// Container Apps Environment
// -------------------------------------------------------
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// -------------------------------------------------------
// ACR reference (admin 資格情報取得用)
// -------------------------------------------------------
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

// -------------------------------------------------------
// Container App
// -------------------------------------------------------
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
        transport: 'auto'
      }
      registries: [
        {
          server: acrLoginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'app'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output containerAppName string = containerApp.name
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
