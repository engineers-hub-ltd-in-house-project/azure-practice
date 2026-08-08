# 第16章 Key Vault ― RBAC 既定化とアクセスポリシーの歴史

Key Vault は、シークレット・暗号鍵・証明書の保管庫です。本章の主題は保管庫そのものよりも、その扉の鍵の掛け方に 2 つの方式が併存しているという事実です。なぜ 2 つあるのか、いまどちらを使うべきか、混在すると何が起きるかを、両方式の Vault を実際に並べて確かめます。

本章の出力はすべて本書の検証環境での実測です。

## 1. このサービスは何のためにあるか

アプリケーションが必要とする秘密の値（DB のパスワード、API キー、証明書）を、コードや設定ファイルの外に置くための専用保管庫です。誰がいつ何を読んだかの監査ログが残り、アクセス制御を保管庫側で一元化できます。

## 2. 縦の依存関係

| 階層               | 効き方                                                                                 |
| ------------------ | -------------------------------------------------------------------------------------- |
| テナント           | Vault は作成時にテナント ID と結び付きます。認証はそのテナントの Entra ID で行われます |
| 管理グループ       | 継承されるポリシーと RBAC。第20章で「旧モデルの Vault を作らせない」統制を掛けます     |
| サブスクリプション | 論理削除された Vault の一覧（`az keyvault list-deleted`）はサブスクリプション単位です  |
| リソースグループ   | ライフサイクル境界。ただし削除後も名前と実体は 90 日残ります（第3章）                  |

名前はストレージ（第15章）と同じく世界で一意です。`<Vault 名>.vault.azure.net` という DNS 名になるためで、論理削除の保持期間中も名前は解放されません。

## 3. 横の繋がり ― 認証認可

Key Vault の認可には歴史があります。

もともと Key Vault は、RBAC（第6章)がデータプレーンに届くより前に生まれたサービスで、独自の仕組みであるアクセスポリシー（誰がシークレット・鍵・証明書それぞれに何をできるかを Vault 自身が持つリスト）で認可していました。その後 RBAC がデータアクションに対応し、Vault の認可も RBAC で書けるようになり、そして現在は新規 Vault の既定が RBAC になっています。実測で確かめます。

### 外向き ― 既定はどちらか

何も指定せずに Vault を作り、認可モデルを見ます。

```bash
az keyvault create --name <Vault名> -g azp-ch16-rg --location japaneast \
  --query "{enableRbacAuthorization:properties.enableRbacAuthorization, accessPolicies:length(properties.accessPolicies)}"
```

```text
{
  "accessPolicies": 0,
  "enableRbacAuthorization": true,
  "name": "azpch16rbac26140"
}
```

既定は RBAC でした（enableRbacAuthorization: true、アクセスポリシー 0 件）。一方、旧モデルを明示して作ると、様子が違います。

```bash
az keyvault create --name <Vault名2> -g azp-ch16-rg --location japaneast \
  --enable-rbac-authorization false --query "{...同上...}"
```

```text
{
  "accessPolicies": 1,
  "enableRbacAuthorization": false,
  "name": "azpch16legacy8360"
}
```

頼んでいないのにアクセスポリシーが 1 件入っています。旧モデルは作成者に全権のポリシーを自動で与える仕様でした。「作った人がすぐ使えて便利」の代償として、作成の瞬間に権限管理の外で権限が生まれていたわけです。RBAC モデルはこれをやめました。作成者であっても、ロールを割り当てるまでデータには触れません。

RBAC のスコープ選択について毎章の確認です。Key Vault のデータロール（Key Vault Secrets Officer / Secrets User など）は Vault 単位のスコープに掛けるのが基本ですが、リソースグループやサブスクリプションにも掛けられます。掛けた範囲のすべての Vault のシークレットに届く、という意味を理解した上で選んでください。

### 内向き

Vault 自身が他へアクセスすることは基本ありません。むしろ第7章のマネージド ID と組み合わせて、アプリが Vault からシークレットを読む形（アプリの ID に Secrets User を割り当てる）が定石です。

## 4. 横の繋がり ― インフラ足回りとネットワーク

SKU は standard と premium の 2 つで、違いは premium が HSM（ハードウェアセキュリティモジュール）保護の鍵を扱えることだけです。シークレットの保管が目的なら standard で足ります。

ネットワークは既定でパブリックエンドポイントです。閉域化は第19章で Functions・Storage と一緒に扱います。

## 5. 横の繋がり ― 契約・課金

純粋な従量課金で、操作の回数（シークレットの取得など 1 万トランザクション単位）に課金されます。保管しているだけでは掛かりません。本書の検証で作る規模では月に 1 円も掛かりません。コスト照会は第14章と同じコマンドです。

## 6. ハンズオン

手順の実体は `scripts/chapters/ch16-key-vault.sh` にあります。新旧 2 つの Vault を並べて作ります。

```bash
./scripts/chapters/ch16-key-vault.sh
./scripts/verify/ch16-key-vault.sh
```

### 壊す演習 ― RBAC Vault に、ロールなしで書いてみる

サブスクリプションの Owner のまま、ロール割り当て前の RBAC Vault にシークレットを書こうとした実際の出力です。

```bash
az keyvault secret set --vault-name <RBAC側Vault名> --name demo --value secret1
```

```text
ERROR: (Forbidden) Caller is not authorized to perform action on resource.
If role assignments, deny assignments or role definitions were changed recently, please observe propagation time.
Caller: appid=...;oid=...;iss=https://sts.windows.net/<テナントID>/
Action: 'Microsoft.KeyVault/vaults/secrets/setSecret/action'
Resource: '.../vaults/azpch16rbac.../secrets/demo'
```

第8章のストレージと同じ構図です。Owner は管理の全権であって、データの権利ではありません。エラーには誰が（Caller）、何の操作で（Action）拒否されたかが正確に出ています。

同じ操作を旧モデルの Vault に対して行うと、自動で入った作成者ポリシーのおかげで即座に成功します。この「新しい Vault では拒否され、古い Vault では通る」という非対称こそ、混在環境の罠です。挙動の違いが認可モデルの違いによるものだと知らなければ、障害調査で迷子になります。ポータルの画面も両者で異なり、RBAC Vault にはアクセスポリシーのタブ自体がありません。

RBAC 側は、ロールを割り当てれば通るようになります。

```bash
az role assignment create --assignee <自分のobjectId> --role "Key Vault Secrets Officer" \
  --scope <RBAC側VaultのリソースID>
```

本書の検証では、伝播を待った 2 回目の試行で書き込みに成功しました。verify の結果です。

```text
==> 第16章の状態を検証する
  OK   無指定で作った Vault の認可モデルが RBAC である
  OK   旧モデル Vault に作成者のアクセスポリシーが自動で入っている
  OK   RBAC Vault にロール経由で書き込めた
  OK   旧モデル Vault にポリシー経由で書き込めた
==> 検証に成功した
```

既存の旧モデル Vault は `az keyvault update --enable-rbac-authorization true` で RBAC へ移行できます。移行した瞬間にアクセスポリシーは無視されるので、先にロール割り当てを揃えてから切り替えます。

### クリーンアップ演習

```bash
./scripts/teardown/ch16-key-vault.sh
```

リソースグループの削除だけでは終わりません。第3章で見たとおり Key Vault は論理削除され、名前が 90 日間予約されます。teardown スクリプトは purge まで実行します。

```bash
az keyvault purge --name <Vault名> --location japaneast
az keyvault list-deleted --query "length(@)" -o tsv
```

```text
0
```

purge が済んで初めて、この章はもう一度最初から実行できます。

### 振り返り

| ブロック   | ハンズオンでの確認箇所                                                              |
| ---------- | ----------------------------------------------------------------------------------- |
| 2 縦       | 論理削除の一覧がサブスクリプション単位。purge で名前解放                            |
| 3 認証認可 | 既定 RBAC の実測。旧モデルの作成者ポリシー自動付与。403 の Caller / Action の読み方 |
| 4 足回り   | standard で十分という判断                                                           |
| 5 課金     | 操作回数課金。保管だけでは無料                                                      |

## 検証環境

| 項目           | 値                                                           |
| -------------- | ------------------------------------------------------------ |
| 検証状態       | verified                                                     |
| 検証日         | 2026-08-08                                                   |
| Azure CLI      | 2.77.0                                                       |
| Bicep CLI      | 0.46.1                                                       |
| API バージョン | Microsoft.KeyVault/vaults@2024-11-01 (RBAC default measured) |

## 理解チェック

1. 同じサブスクリプションに RBAC モデルと旧モデルの Vault が混在しています。あるユーザーが「Vault A ではシークレットを読めるのに Vault B では 403 になる」と報告してきました。調査の最初の 1 コマンドは何ですか
2. 旧モデルの Vault を `--enable-rbac-authorization true` で移行する前に、必ずやるべき準備は何ですか。移行の瞬間に何が無視されるかから逆算してください
3. 本章の teardown で purge を忘れたまま 1 週間後に章を再実行すると、どこでどんなエラーになりますか。CLI と Bicep で挙動が違う点（第3章）も含めて答えてください
