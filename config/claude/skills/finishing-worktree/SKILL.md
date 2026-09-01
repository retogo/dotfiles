---
name: finishing-worktree
description: worktree での作業を終わらせる。worktree を出てベースブランチへ merge → push → worktree とブランチを削除するまでを一括で行う。「worktree を出て main にマージして push して cleanup」「worktree 片付けて」「作業ブランチ取り込んで消して」などのリクエストで発動。
allowed-tools: Bash, ExitWorktree
---

# worktree の後始末

worktree での作業が終わった状態から、merge → push → cleanup までを流れで実行する。
軽い後始末なので、確認は最小限でよい。想定外のことが起きたらその場で判断する。

引数でベースブランチを指定できる（`/finishing-worktree staging`）。省略時は「2. ベースブランチを決める」で判定する。

## 手順

### 1. 作業内容を確定する

```sh
git status --short
git log --oneline -3
```

未コミットの変更があれば commit する。変更が意図しないもの（デバッグ用の一時ファイル等）なら消してから進める。

### 2. ベースブランチを決める

引数指定があればそれを使う。無ければ次の順で決める。

```sh
git symbolic-ref --quiet refs/remotes/origin/HEAD   # origin のデフォルトブランチ
git branch --list staging main master
```

`staging` があるリポジトリでは `staging` を優先する（開発ブランチは staging から切られているため）。判断がつかなければユーザーに聞く。

### 3. worktree を出る

**merge より先に必ず worktree を出る。** worktree の中からは元のチェックアウトに対する git 操作ができない。

- EnterWorktree で入った worktree なら `ExitWorktree` を **`action: "keep"`** で呼ぶ
  （`remove` はこの時点ではブランチごと消えてしまうので使わない。削除は手順 5 で行う）
- 手動で作った worktree なら、元のチェックアウトのディレクトリへ移動する

### 4. merge して push

```sh
git switch <base>
git merge --ff-only <branch>
git push origin <base>
```

`--ff-only` が失敗するのは base が先に進んでいる場合。その時は `git merge <branch>`（マージコミット）か、作業ブランチを rebase してからやり直すかを選ぶ。

### 5. cleanup

```sh
git worktree remove <worktree-path>
git branch -d <branch>
git push origin --delete <branch>   # remote に push 済みの場合のみ
```

- `git branch -d` は未 merge だと失敗する。これが安全弁なので `-D` で潰さない
- `git worktree remove` が未コミット変更を理由に失敗したら、中身を確認してから `--force` を判断する
- **自分が作っていない worktree・ブランチには触らない。** `git worktree list` に他の worktree があっても cleanup 対象に含めない

### 6. 確認して報告

```sh
git status --short
git log --oneline -3
git worktree list
```

merge した commit・push 先・削除したもの（worktree / local branch / remote branch）を報告する。
