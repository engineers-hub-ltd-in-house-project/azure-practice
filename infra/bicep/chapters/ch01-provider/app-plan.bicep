// 第1章 壊す演習の経路 2 で使う最小のテンプレート。
// Microsoft.Web が未登録のサブスクリプションでも、az deployment はデプロイ前に
// プロバイダーを自動登録するため、このデプロイは成功する（実測済み）。
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
