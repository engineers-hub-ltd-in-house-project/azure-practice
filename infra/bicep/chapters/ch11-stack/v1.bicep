// 第11章 v1: リソース 2 つの構成。
// v2.bicep との差分（app2 の削除）を、通常デプロイとスタックの両方で適用して
// 挙動の違いを観察する。素材には無料で作成が速いマネージド ID を使う。

param location string = resourceGroup().location

resource app1 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'azp-ch11-app1'
  location: location
}

resource app2 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'azp-ch11-app2'
  location: location
}
