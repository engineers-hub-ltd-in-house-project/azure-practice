# Deployment Stacks

スタックを使う章の定義と操作の所在。

- スタックで宣言するテンプレートは `infra/bicep/chapters/ch11-stack/` と `infra/bicep/chapters/ch13-iac-rebuild/` にある
- スタックの作成・検証・削除は、他の章と同じく `scripts/chapters/` `scripts/verify/` `scripts/teardown/` の章スクリプトが担う

`az stack` は `--action-on-unmanage` の指定を誤ると、テンプレートから外れたリソースを意図せず削除する。指定は章スクリプト側で固定してあり、手で打つ場合は第11章を読んでから使うこと。
