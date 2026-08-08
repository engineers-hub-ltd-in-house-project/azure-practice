# Deployment Stacks

第11章「デプロイスコープと Deployment Stacks」および第13章の統合ハンズオンで使う、スタックの作成・更新・削除のラッパを置く。

`az stack sub` / `az stack group` は `--action-on-unmanage` の指定を誤ると、テンプレートから外れたリソースを意図せず削除する。指定を毎回手で打たせないため、章ごとのラッパをここに置いてスクリプト側で固定する。
