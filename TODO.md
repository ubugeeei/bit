# TODO (Active Only)

最終整理日: 2026-03-15
方針: 完了ログは一旦外し、未完了タスクのみ管理する。
現バージョン: v0.29.0
allowlist: 906 テスト（重複除去済み）
CI unit test: **1632/1632 全パス** (2026-03-15)

## P0: Git compatibility — CI git-compat 失敗削減

### 横断カテゴリ別サマリ

| カテゴリ | テスト数 | 合計失敗数 | 主要テスト |
|----------|----------|------------|------------|
| **Merge engine** | 5 | 56 | t6416, t6422, t6423, t6424, t6426 |
| **rev-parse** | 3 | 48 | t1506(22), t1512(22), t1500(4) |
| **Sparse/Index** | 5 | 44 | t1092(14), t7002(14), t3903(13), t1091(1), t3705(2) |
| **Reftable/Refs** | 3 | 42 | t1460(25), t0610(14), t1463(3) |
| **Object/Hash** | 3 | 110 | t1451(62), t1006(31), t1007(17) |
| **Worktree** | 4 | 13 | t2402(5), t1415(5), t2404(2), t2400(1) |
| **Submodule** | 3 | 14 | t7400(8), t3207(4), t7424(2) |
| **Pack/MIDX** | 5 | 24 | t5323(14), t5319(4), t5334(2), t5306(2), t5313(2) |

### スコープ外

- **t1016-compatObjectFormat.sh** (181/202) — SHA-256 compat
- **t9700-perl-git.sh** (1/3) — Perl Git.pm
- **t7510-signed-commit.sh** (1/28) — GPG 署名検証
- **t7528-signed-commit-ssh.sh** (1/26) — SSH 署名検証
- **t0610-reftable-basics.sh** (14/91) — reftable format
- **t1460-refs-migrate.sh** (25/37) — reftable migration

完了済みタスクは [docs/DONE.md](docs/DONE.md) を参照。

## P1: Relay / P2P collaboration

- [ ] SSH clone の JS target 対応（Issue #18）
  - [ ] HTTP smart protocol で JS 対応

## P2: パフォーマンス

- [ ] 大規模リポジトリでのベンチマーク継続（clone/fetch/status/log）

### pack-objects 高速化 (10-20x 遅い → 目標 2x 以内)

ベースライン (2026-03-04): E2E で 500obj bit=1970ms vs git=101ms (19.5x)
ボトルネック: zlib (55%) + MoonBit ランタイム起動 (~150ms)

- [ ] **RefDelta base SHA-1 キャッシュ** (低優先)
- [ ] **オブジェクトのソート (type + size desc)** — デルタ効率向上
- [ ] **スライディングウィンドウ (--window)** — 直近N個を候補に
- [ ] **build_delta のブロックインデックス再利用**
- [ ] **find_best_match の候補数制限緩和** (64 → 128-256)

## P3: Git互換の残タスク

### allowlist 残り

- t0: t0012, t0450（`-h` テスト、shim コマンドの出力不一致）
- t4: t4137（apply submodule、4/28 failures）
- t7: t7450（test-tool submodule 依存）
- t9: svn/cvs/p4 は明示的にサポート外

### その他

- [ ] `--help` 移植: 外部 help テキスト実体の整備（必要コマンド分）

## P3.5: realgit 委譲の削減

方針: CI SHIM_STRICT=1 で bit に通すコマンドを段階的に増やす。
CI SHIM_CMDS: 56 コマンド (init add diff diff-files diff-index ls-files tag branch checkout switch commit log show reflog reset update-ref update-index status merge rebase clone push fetch pull mv notes stash rm submodule worktree config show-ref for-each-ref rev-parse symbolic-ref cherry-pick remote cat-file hash-object ls-tree write-tree commit-tree receive-pack upload-pack pack-objects index-pack format-patch describe gc clean sparse-checkout restore blame grep shell rev-list bisect)

### Tier 1: 超高頻度（1000+ 呼出）
- [x] `checkout` (3765)
- [x] `commit` (3596)
- [x] `add` (3268)
- [x] `reset` (1923)
- [x] `branch` (1749)
- [x] `init` (1667)
- [x] `tag` (1199)
- [x] `diff` (1196)
- [x] `log` (1173)
- [x] `ls-files` (1162)

### Tier 2: 高頻度（400–999 呼出）
- [x] `rebase` (991)
- [x] `clone` (953)
- [x] `merge` (889)
- [x] `update-ref` (824)
- [x] `update-index` (720)
- [x] `status` (608)
- [x] `push` (534)
- [x] `notes` (600)
- [x] `submodule` (603)
- [x] `rev-list` (521) — CI SHIM_CMDS 追加済み、date order デフォルト化
- [x] `fetch` (461)
- [x] `mv` (488)
- [x] `stash` (472)
- [x] `rm` (470)
- [x] `worktree` (421)
- [x] `bisect` (420) — run/replay/visualize/terms 実装、CI SHIM_CMDS 追加済み

### Tier 3-4: 中低頻度
- [x] `apply` (398) — --stat/--summary git互換 (t4100: 19/19)
- [x] `show` (362)
- [x] `symbolic-ref` (335)
- [x] `cherry-pick` (324)
- [x] `grep` (312)
- [x] `repack` (302) — pack-objects 委譲、update-server-info (t7700: 23/47)
- [x] `format-patch` (300)
- [x] `remote` (298)
- [x] `reflog` (296)
- [x] `switch` (251)
- [x] `pull` (250)
- [x] `clean` (232)
- [x] `diff-index` (219), `diff-files` (170)
- [x] `restore` (117)
- [x] `sparse-checkout` (113)
- [x] `blame` (110)
- [x] `gc` (81)
- [x] `describe` (53)

### 未実装コマンド（新規実装候補）
- [ ] `am` (235), `diff-tree` (224), `fast-import` (196), `read-tree` (176)
- [ ] `fsck` (159), `commit-graph` (137), `multi-pack-index` (133)
- [ ] `ls-remote` (127), `bundle` (110), `stripspace` (108)

### rev-list git-compat 改善
- [ ] pathspec フィルタリング (t6000 tests 2-4)
- [ ] `--unpacked` (t6000 test 18)
- [ ] topo-order 精度向上 (t6003)
- [ ] `--header` NUL 出力改善 (t6000 test 14)

### repack 改善
- [ ] bitmap 生成 (t7700 tests 2,6,15,21,30,33,35)
- [ ] `--write-midx` (t7700 tests 28-36)
- [ ] alternate ODB 処理 (t7700 tests 4,5,10,11)
- [ ] `--filter` パススルー (t7700 tests 22-26)

## P4: WASM / クロスプラットフォーム

- [ ] WASM target での機能カバレッジ拡大
- [ ] JS target の SSH clone 代替（HTTP smart protocol 検討）→ Issue #18

## P5: プラットフォーム/将来タスク

- [ ] Moonix integration: ToolEnvironment <-> AgentRuntime（moonix release 待ち）
- [ ] bit mount: ファイルシステムにマウントする機能
- [ ] bit mcp: MCP 対応
- [ ] BIT~ 環境変数の対応
- [ ] `.bitignore` 対応
- [ ] `.bit` 対応（`.git` → `.bit` ディレクトリ切替）
- [ ] bit jj: jj 相当の対応
