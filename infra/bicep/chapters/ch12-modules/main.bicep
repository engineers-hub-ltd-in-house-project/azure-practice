// 第12章 自作モジュールと AVM モジュールを並べて使う。
// 前者は本リポジトリの modules/、後者は公式レジストリ（br/public:）から取得される。

param location string = resourceGroup().location
param storageName string

// 自作モジュール。相対パスで参照する。
module storage '../../modules/keyless-storage.bicep' = {
  name: 'keyless-storage'
  params: {
    name: storageName
    location: location
  }
}

// AVM モジュール。公式レジストリからバージョン指定で取得する。
module identity 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = {
  name: 'avm-identity'
  params: {
    name: 'azp-ch12-id'
    location: location
  }
}

output storageId string = storage.outputs.id
output identityPrincipalId string = identity.outputs.principalId
