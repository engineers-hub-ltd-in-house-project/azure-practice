// 第1章 壊す演習の経路 2 で使う最小のテンプレート。
//
// Microsoft.Web が未登録のサブスクリプションでも、az deployment はデプロイ前に
// プロバイダーを自動登録する（実測済み）。ただし作りたての従量課金サブスクリプション
// では App Service の仮想マシン枠の上限が 0 のことがあり、その場合デプロイ自体は
// クォータ不足で失敗する（実測済み）。それでも登録は先に完了しており、
// この「登録は成功・作成は失敗」の非対称を観察するのが本テンプレートの目的である。
// 素の MissingSubscriptionRegistration は az rest の直接 PUT でのみ観察できる。

param location string = resourceGroup().location

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'azp-ch01-plan'
  location: location
  sku: {
    name: 'F1'
    tier: 'Free'
  }
}
