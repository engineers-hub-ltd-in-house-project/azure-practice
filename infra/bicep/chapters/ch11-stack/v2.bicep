// 第 11 章 v2: v1 から app2 を消した構成。「テンプレートから消す」ことが
// 実リソースの削除を意味するかどうかは、適用の方法で変わる。

param location string = resourceGroup().location

resource app1 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'azp-ch11-app1'
  location: location
}
