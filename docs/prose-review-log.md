# 散文レビュー台帳

各章を、どの規約版で読み直したかを記録する。`docs/verification-log.md` がコマンドの実測状態を追うのに対し、この台帳は文章の状態を追う。

必要な理由は履歴にある。全 27 章は 2026-08-08 に書かれ、その時点の `.claude/rules/lessons.md` は 8〜15 条だった。その後、指摘のたびに条文が増えて 38 条になった。増えた条は次に書く文章にしか効いておらず、原稿は書いた時点の版で固定されたままだった。結果として、読者が開いた章が毎回「現行規約での初読」になり、同じ種類の指摘が章ごとに出続けた。

`scripts/lint/review-lint.mjs` が、全章の版が `WRITING_GUIDELINES.md` の現行版と一致することを検査する。規約を 1 条足したら版を進め、全章を新しい条で読み直すまで CI は赤のままになる。

| 章                                                                                                                             | 規約版 | レビュー日 | 備考 |
| ------------------------------------------------------------------------------------------------------------------------------ | ------ | ---------- | ---- |
| [第 0 章 Azure を使い始める ― アカウント作成からサブスクリプションまで](../manuscript/part1/00-getting-started.md)             | 0      | -          | -    |
| [第 1 章 テナントとサブスクリプション ― 契約と分離の境界](../manuscript/part1/01-tenant-and-subscription.md)                   | 0      | -          | -    |
| [第 2 章 管理グループ ― ポリシーと RBAC が上から下に伝わる仕組み](../manuscript/part1/02-management-groups.md)                 | 0      | -          | -    |
| [第 3 章 リソースグループ ― ライフサイクルをまとめる単位の設計](../manuscript/part1/03-resource-groups.md)                     | 0      | -          | -    |
| [第 4 章 ハンズオン ― 4 階層を 1 つのシナリオで通しで作る](../manuscript/part1/04-hands-on-four-layers.md)                     | 0      | -          | -    |
| [第 5 章 Entra ID の基本 ― ユーザー・グループ・サービスプリンシパル・マネージド ID](../manuscript/part2/05-entra-id-basics.md) | 0      | -          | -    |
| [第 6 章 RBAC ― スコープとロールの組み合わせで権限が決まる](../manuscript/part2/06-rbac.md)                                    | 0      | -          | -    |
| [第 7 章 マネージド ID ― リソース間の内向き認証](../manuscript/part2/07-managed-identity.md)                                   | 0      | -          | -    |
| [第 8 章 外向き認証 ― アクセスキー・Entra ID 認証・フェデレーションの使い分け](../manuscript/part2/08-outbound-auth.md)        | 0      | -          | -    |
| [第 9 章 ハンズオン ― ID と権限を 1 つのシナリオで通す](../manuscript/part2/09-hands-on-identity.md)                           | 0      | -          | -    |
| [第 10 章 ARM テンプレートと Bicep の関係](../manuscript/part3/10-arm-and-bicep.md)                                            | 0      | -          | -    |
| [第 11 章 デプロイスコープと Deployment Stacks](../manuscript/part3/11-deployment-scopes-and-stacks.md)                        | 0      | -          | -    |
| [第 12 章 モジュール化と Azure Verified Modules](../manuscript/part3/12-modules-and-avm.md)                                    | 0      | -          | -    |
| [第 13 章 ハンズオン ― 第 1〜2 部の構成を IaC で再現する](../manuscript/part3/13-hands-on-iac.md)                              | 0      | -          | -    |
| [第 14 章 Functions ― Flex Consumption を軸に課金とネットワークの関係を辿る](../manuscript/part4/14-functions.md)              | 0      | -          | -    |
| [第 15 章 Storage ― Functions の隠れた依存関係から理解する](../manuscript/part4/15-storage.md)                                 | 0      | -          | -    |
| [第 16 章 Key Vault ― RBAC 既定化とアクセスポリシーの歴史](../manuscript/part4/16-key-vault.md)                                | 0      | -          | -    |
| [第 17 章 AKS ― 5 つの ID scenario と Workload ID](../manuscript/part4/17-aks.md)                                              | 0      | -          | -    |
| [第 18 章 Cosmos DB ― コントロールプレーンとデータプレーンの RBAC は別物](../manuscript/part4/18-cosmos-db.md)                 | 0      | -          | -    |
| [第 19 章 Networking ― VNet 統合と Private Endpoint が各層にどう効くか](../manuscript/part4/19-networking.md)                  | 0      | -          | -    |
| [第 20 章 Azure Policy ― 強制（Deny）と監査（Audit）の違い](../manuscript/part5/20-azure-policy.md)                            | 0      | -          | -    |
| [第 21 章 Cloud Adoption Framework と Landing Zone](../manuscript/part5/21-caf-and-landing-zone.md)                            | 0      | -          | -    |
| [第 22 章 マルチサブスクリプション設計の実践](../manuscript/part5/22-multi-subscription.md)                                    | 0      | -          | -    |
| [第 23 章 コストの見方 ― タグとスコープで課金を切り分ける](../manuscript/part5/23-cost-management.md)                          | 0      | -          | -    |
| [第 24 章 1 つのアプリケーションをゼロから設計し、全階層を貫通させる](../manuscript/part6/24-capstone.md)                      | 0      | -          | -    |
| [付録 A 型の適用シート](../manuscript/appendix/a-worksheet.md)                                                                 | 0      | -          | -    |
| [付録 B 命名規約とタグ設計](../manuscript/appendix/b-naming-and-tags.md)                                                       | 0      | -          | -    |
