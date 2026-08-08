// 第4章 [統合ハンズオン] 4 階層を 1 つのシナリオで通しで作る
//
// このテンプレートはサブスクリプションスコープにデプロイする。リソースグループの作成そのものが
// サブスクリプションスコープの操作であり、リソースグループスコープからは書けないためである。
// スコープの選択がテンプレートの書ける内容を決めるという第11章の主題は、ここで既に現れている。

targetScope = 'subscription'

@description('本書のハンズオンが作るリソースに共通で付ける接頭辞')
param prefix string = 'azp'

@description('リソースグループを作るリージョン')
param location string = 'japaneast'

@description('章を識別するためのタグ。teardown がこのタグで対象を絞る')
param chapter string = 'ch04'

// 一緒に消えるべきものをまとめる、というリソースグループの設計原則に従い、
// この章で作るものはすべて 1 つのリソースグループに入れる。
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: '${prefix}-${chapter}-rg'
  location: location
  tags: {
    'azp-book': 'azure-practice'
    'azp-chapter': chapter
    'azp-lifecycle': 'ephemeral'
  }
}

// リソースグループの中身は、リソースグループスコープのモジュールに委ねる。
// スコープが違うものを 1 つのファイルに混ぜられないという制約が、
// モジュール分割の動機になっている（第12章）。
module contents 'contents.bicep' = {
  name: '${prefix}-${chapter}-contents'
  scope: rg
  params: {
    prefix: prefix
    chapter: chapter
    location: location
  }
}

output resourceGroupName string = rg.name
output storageAccountName string = contents.outputs.storageAccountName
output userAssignedIdentityName string = contents.outputs.userAssignedIdentityName
output userAssignedIdentityPrincipalId string = contents.outputs.userAssignedIdentityPrincipalId
