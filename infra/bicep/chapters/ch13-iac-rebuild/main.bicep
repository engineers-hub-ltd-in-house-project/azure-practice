// 第13章 ハンズオン ― 第1〜2部の構成を IaC で再現する
//
// 第4章（az コマンドの積み上げ）と第9章（ID と権限のシナリオ）で作った構成を、
// サブスクリプションスコープのスタック 1 本で宣言し直す。
// includeStorage を false にして再適用すると、actionOnUnmanage の設定に従って
// ストレージとロール割り当てが掃除される（第11章の挙動を実構成で使う）。

targetScope = 'subscription'

param location string = 'japaneast'
param storageName string

@description('false にするとストレージ（とそのロール割り当て）が構成から外れる')
param includeStorage bool = true

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'azp-ch13-rg'
  location: location
  tags: {
    'azp-book': 'azure-practice'
    'azp-chapter': 'ch13'
    'azp-lifecycle': 'ephemeral'
  }
}

module contents 'contents.bicep' = {
  name: 'azp-ch13-contents'
  scope: rg
  params: {
    location: location
    storageName: storageName
    includeStorage: includeStorage
  }
}

output identityPrincipalId string = contents.outputs.identityPrincipalId
