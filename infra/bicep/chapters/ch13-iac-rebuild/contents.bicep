// 第13章 リソースグループの中身。
// ストレージは第12章で切り出した自作モジュールを使う。ID は AVM を使う。
// 「検証済みモジュールを組み合わせ、足りない部分（ロール割り当て）だけ書く」形。

param location string
param storageName string
param includeStorage bool

module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = {
  name: 'azp-ch13-identity'
  params: {
    name: 'azp-ch13-id'
    location: location
  }
}

module storage '../../modules/keyless-storage.bicep' = if (includeStorage) {
  name: 'azp-ch13-storage'
  params: {
    name: storageName
    location: location
  }
}

// 第9章と同じく、アプリの ID には RG スコープでデータロールを配る。
var storageBlobDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (includeStorage) {
  name: guid(resourceGroup().id, 'azp-ch13-id', storageBlobDataContributor)
  properties: {
    roleDefinitionId: storageBlobDataContributor
    principalId: identity.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

output identityPrincipalId string = identity.outputs.principalId
