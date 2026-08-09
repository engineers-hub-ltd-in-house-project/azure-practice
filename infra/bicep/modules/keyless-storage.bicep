// 本書の全章で繰り返し登場する「生まれつきキー無効のストレージ」を切り出した自作モジュール。
// 第 4 章・第 9 章・第 10 章で同じ 5 行の properties を 3 回書いた。3 回書いたら切り出す。

@description('ストレージアカウント名。グローバルに一意で、英小文字と数字のみ 3〜24 文字')
@minLength(3)
@maxLength(24)
param name string

@description('リージョン。既定はリソースグループに合わせる')
param location string = resourceGroup().location

@description('冗長性。検証用途は Standard_LRS で足りる')
param skuName string = 'Standard_LRS'

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: name
  location: location
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

@description('データプレーンのロール割り当てに使うリソース ID')
output id string = storage.id
output name string = storage.name
