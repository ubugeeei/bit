# TODO (Active Only)

最終整理日: 2026-03-16
方針: 完了ログは一旦外し、未完了タスクのみ管理する。
現バージョン: v0.30.0
allowlist: 908 テスト（重複除去済み）
CI SHIM_CMDS: **73 コマンド**
CI unit test: **1632/1632 全パス** (2026-03-15)
e2e: **30/30 全パス** (2026-03-16)

## P0: Git compatibility — CI git-compat

### 実装済みコマンド (73 SHIM_CMDS)

```
init add diff diff-files diff-index ls-files tag branch checkout switch
commit log show reflog reset update-ref update-index status merge rebase
clone push fetch pull mv notes stash rm submodule worktree config show-ref
for-each-ref rev-parse symbolic-ref cherry-pick remote cat-file hash-object
ls-tree write-tree commit-tree receive-pack upload-pack pack-objects
index-pack format-patch describe gc clean sparse-checkout restore blame
grep shell rev-list bisect diff-tree read-tree fsck am apply bundle cherry
revert prune pack-refs mktree shortlog verify-pack unpack-objects
maintenance range-diff show-branch repack
```

### 主要テスト結果 (ローカル確認済み)

| テスト | 結果 | 備考 |
|--------|------|------|
| t1300-config | 485/485 | 全パス |
| t1450-fsck | 95/95 | 全パス（新規実装） |
| t3200-branch | 167/167 | 全パス |
| t3501-revert-cherry-pick | 21/21 | 全パス |
| t5300-pack-object | 52/52 | 全パス |
| t5510-fetch | 215/215 | 全パス |
| t6300-for-each-ref | 427/428 | SSH 署名検証のみ失敗 |
| t6301-for-each-ref-errors | 6/6 | 全パス |
| t6302-for-each-ref-filter | 62/62 | 全パス |
| t6101-rev-parse-parents | 38/38 | 全パス |
| t7700-repack | 25/47 | bitmap/MIDX 未実装 |
| t7003-filter-branch | 48/48 | 全パス |

### 横断カテゴリ別 未対応サマリ

| カテゴリ | テスト数 | 合計失敗数 | 主要テスト |
|----------|----------|------------|------------|
| **Merge engine** | 5 | 56 | t6416, t6422, t6423, t6424, t6426 |
| **Sparse/Index** | 5 | 44 | t1092(14), t7002(14), t3903(13), t1091(1), t3705(2) |
| **Reftable/Refs** | 3 | 42 | t1460(25), t0610(14), t1463(3) |
| **Object/Hash** | 3 | 110 | t1451(62), t1006(31), t1007(17) |

### スコープ外

- **t1016-compatObjectFormat.sh** — SHA-256 compat
- **t9700-perl-git.sh** — Perl Git.pm
- **t7510-signed-commit.sh** — GPG 署名検証
- **t7528-signed-commit-ssh.sh** — SSH 署名検証
- **t0610-reftable-basics.sh** — reftable format
- **t1460-refs-migrate.sh** — reftable migration
- **t9*-svn/cvs/p4** — 明示的にサポート外

## P0.5: 未実装機能 (README に記載済み)

### 根本的に未実装

- [ ] SHA-256 リポジトリ
- [ ] Reftable バックエンド
- [ ] Bitmap ファイル書き出し (`pack-objects --write-bitmap-index`)
- [ ] Multi-pack-index 書き出し (`repack --write-midx`)
- [ ] Commit-graph 生成・読込
- [ ] SSH トランスポート (HTTPS のみ)
- [ ] GPG/SSH 署名 (`commit -S`, `tag -s`)
- [ ] Interactive add (`add -p` / `add -i` は git 委譲)
- [ ] Interactive rebase (`rebase -i` はスタンドアロンで拒否)
- [ ] Custom merge drivers

### repack 残タスク (t7700: 25/47)

| カテゴリ | テスト数 | 理由 |
|----------|----------|------|
| `--write-midx` | 9 | MIDX 生成未実装 |
| `--filter` (高度) | 5 | `test-tool find-pack` 依存 |
| Alternate ODB | 4 | エッジケース |
| Bitmap 書き出し | 2 | `.bitmap` ファイル生成未実装 |
| `GIT_TRACE2_EVENT` | 1 | git 内部トレーシング、対応不可 |
| Pending objects | 1 | `--path-walk` + fsck 出力形式 |

### allowlist 残り (未追加テスト)

- t0012, t0450 (`-h` テスト、shim コマンドの出力不一致)
- t4137 (apply submodule、4/28 failures)
- t7450 (test-tool submodule 依存)
- t9 系: svn/cvs/p4 は明示的にサポート外

## P1: Relay / P2P collaboration

- [ ] SSH clone の JS target 対応（Issue #18）
  - [ ] HTTP smart protocol で JS 対応

## P2: パフォーマンス

- [ ] 大規模リポジトリでのベンチマーク継続（clone/fetch/status/log）

### pack-objects 高速化 (10-20x 遅い → 目標 2x 以内)

ベースライン (2026-03-04): E2E で 500obj bit=1970ms vs git=101ms (19.5x)
ボトルネック: zlib (55%) + MoonBit ランタイム起動 (~150ms)

- [ ] **スライディングウィンドウ (--window)** — 直近N個を候補に
- [ ] **build_delta のブロックインデックス再利用**
- [ ] **find_best_match の候補数制限緩和** (64 → 128-256)

## P3: WASM / クロスプラットフォーム

- [ ] WASM target での機能カバレッジ拡大
- [ ] JS target の SSH clone 代替（HTTP smart protocol 検討）→ Issue #18

## P4: プラットフォーム/将来タスク

- [ ] Moonix integration: ToolEnvironment <-> AgentRuntime（moonix release 待ち）
- [ ] bit mount: ファイルシステムにマウントする機能
- [ ] bit mcp: MCP 対応
- [ ] `.bitignore` 対応
- [ ] `.bit` 対応（`.git` → `.bit` ディレクトリ切替）
- [ ] bit jj: jj 相当の対応
