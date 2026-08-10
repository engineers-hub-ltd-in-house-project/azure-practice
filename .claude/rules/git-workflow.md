# Git / main で作業する

- 作業ブランチは切らない。変更は main で行い、main へ直接コミットする。PR も作らない
- コミットしたら push まで済ませる。更新後は常にローカルの main とリモートの main を一致させる。手元にだけあるコミットを残さない
- push の前に `npm run lint` と `npm run lint:self` を通す。push したら CI の結論を確認し、落ちたら次の作業より先に直す
- バックグラウンドジョブで worktree を強制された場合は、作業をそこで終わらせない。main へ戻すところまでが 1 セットである

  1. worktree 上でコミットする
  2. ExitWorktree（keep）でメインのチェックアウトへ戻る
  3. `git merge --ff-only <worktree のブランチ>`
  4. `git worktree remove <worktree のパス>` と `git branch -d <ブランチ>` で片付ける
  5. `git push`

- 巻き戻す push は禁止（`~/.claude/rules/no-rewrite-push.md`）。main で作業する場合も変わらない

## 背景

worktree 上のブランチにコミットを残したまま終えると、ユーザーが毎回 merge を指示することになる。
worktree はセッションと一緒に消えるため、残骸のブランチだけが増える。main へ入れて push するまでを
エージェント側で完了させる。

`.claude/settings.json` に `{"worktree": {"bgIsolation": "none"}}` を置けば、バックグラウンドジョブも
最初から main のチェックアウトで作業でき、上の 5 手順は不要になる。ただし並行して走らせたジョブが
同じチェックアウトを共有するため、その場合はジョブを 1 つずつ流す。
