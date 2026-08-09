// 第 4 章 リソースグループの中身。
// ストレージアカウントは「リソースグループと運命を共にするもの」の例、
// ユーザー割り当てマネージド ID は「リソースグループを消しても Entra ID 側には別の実体が残る」
// ことを観察するための例として置いている（第 3 章・第 7 章）。

@description('本書のハンズオンが作るリソースに共通で付ける接頭辞')
param prefix string

@description('章を識別するためのタグ')
param chapter string

@description('リージョン')
param location string

// ストレージアカウント名はグローバルに一意でなければならず、英小文字と数字のみ 24 文字以内。
// この制約がリソース種別ごとに違う理由は付録 Bで扱う。
var storageAccountName = take('${prefix}${chapter}${uniqueString(resourceGroup().id)}', 24)

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    // キー認証を止める。第 8 章で扱う「キー認証をポリシーで無効化していく潮流」の最小形。
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
  }
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: '${prefix}-${chapter}-id'
  location: location
}

// 内向きの認証。マネージド ID にストレージのデータプレーンロールを与える。
// スコープはストレージアカウント（リソース）であり、リソースグループでもサブスクリプションでもない。
// RBAC のスコープ選択がガバナンス階層と一致するとは限らない、という第 6 章の主題の実例。
var storageBlobDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, identity.id, storageBlobDataContributor)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributor
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output storageAccountName string = storage.name
output userAssignedIdentityName string = identity.name
output userAssignedIdentityPrincipalId string = identity.properties.principalId
