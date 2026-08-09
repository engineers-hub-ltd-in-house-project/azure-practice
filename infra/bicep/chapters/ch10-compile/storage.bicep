// 第 10 章 コンパイルの観察に使う最小のテンプレート。
// bicep build でこのファイルが ARM JSON に何行で変換されるかを見る。

param location string = resourceGroup().location
param name string

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}
