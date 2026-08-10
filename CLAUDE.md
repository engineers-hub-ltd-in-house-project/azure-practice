# azure-practice

ガバナンス階層から積み上げる Azure 自習書。原稿・IaC・検証スクリプトを 1 つに保つ。

## 検証コマンド

```bash
npm run lint                                          # 書式・章構成・Mermaid・実在識別子の検査
find scripts -name '*.sh' -print0 | xargs -0 shellcheck -x
az bicep build --file <対象>.bicep --stdout > /dev/null
```

コミット前に必ず npm run lint を通す。push 後は CI の結論を確認する。

## 執筆の規律

- 執筆規約は WRITING_GUIDELINES.md が正。6 ブロックの型・ですます調・太字禁止・略語定義・検証ポリシーはそこにある
- 実行コマンドは実機検証したものだけを書く。検証したら scripts/record-verification.sh <章番号> <状態> [API バージョン] で記録する。docs/verification-log.md は手で編集しない
- 本文にコマンド列を直接埋め込まず、scripts/ と infra/ の実ファイルを参照させる
- ハンズオンは検証用サンドボックスでのみ実行する。顧客・本番サブスクリプションでは実行しない

## Git の運用

@.claude/rules/git-workflow.md

## 過去の指摘

@.claude/rules/lessons.md
