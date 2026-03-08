# TODO (Active Only)

最終整理日: 2026-03-08
方針: 完了ログは一旦外し、未完了タスクのみ管理する。
現バージョン: v0.26.3
allowlist: 906 テスト（重複除去済み）
CI 失敗: **105/906** (2026-03-08, commit b85e6c5)

## P0: Git compatibility — CI 失敗削減

### Easy Wins (1-2 failures, 高ROI)

- [ ] **t6006-rev-list-format.sh** (1/80) — empty email formatting
- [ ] **t3200-branch.sh** (1/167) — reflog with `core.logAllRefUpdates=false`
- [ ] **t6120-describe.sh** (1/103) — misnamed annotated tag forces long output
- [ ] **t6002-rev-list-bisect.sh** (1/53) — `--bisect` default refs
- [ ] **t8008-blame-formats.sh** (1/5) — porcelain subject detection
- [ ] **t1350-config-hooks-path.sh** (1/4) — `--git-path hooks`
- [ ] **t3300-funny-names.sh** (1/21) — ls-tree quoting
- [ ] **t0090-cache-tree.sh** (1/22) — write-tree cache-tree
- [ ] **t7102-reset.sh** (1/38) — `reset -N` intent-to-add
- [ ] **t4010-diff-pathspec.sh** (1/17) — multiple wildcard pathspecs
- [ ] **t5318-commit-graph.sh** (1/109) — stale commit parse
- [ ] **t2203-add-intent.sh** (1/19) — cache-tree empty dir

### 中規模 (数テスト修正で解消見込み)

- [ ] **t6300-for-each-ref.sh** (11/428) — signatures, `contents:body` signed tag, `trailers:separator=`
- [ ] **t1400-update-ref.sh** (4/313) — date-based reflog `main@{date}:F`, per-worktree refs
- [ ] **t1500-rev-parse.sh** (4/81) — `--path-format`, `--show-ref-format`, superproject
- [ ] **t6101-rev-parse-parents.sh** (9/38) — `^@`, `^!`, `^-` parent suffix
- [ ] **t7700-repack.sh** (5/47) — alternate ODB, `--filter-to`, pending objects
- [ ] **t5510-fetch.sh** (4/215) — atomic fetch, branch merge config

### 大規模カテゴリ (横断的な対応が必要)

#### rev-parse 拡張 (~45 failures)
- [ ] **t1506-rev-parse-diagnosis.sh** (22/30) — pathspec/revision 曖昧性解消、`--` handling
- [ ] **t1512-rev-parse-disambiguation.sh** (23/35) — ambiguous object resolution

#### Merge engine (~57 failures)
- [ ] **t6416-recursive-corner-cases.sh** (13/37) — criss-cross merge
- [ ] **t6422-merge-rename-corner-cases.sh** (14/19) — rename/add conflict
- [ ] **t6423-merge-rename-directories.sh** (17/80) — directory rename
- [ ] **t6424-merge-unrelated-index-changes.sh** (11/19) — index preservation

#### Reftable / Ref Storage (~42 failures)
- [ ] **t0610-reftable-basics.sh** (14/91)
- [ ] **t1460-refs-migrate.sh** (25/37)

#### hash-object / Object Validation (~118 failures)
- [ ] **t1451-fsck-buffer.sh** (62/72) — truncated commit fsck
- [ ] **t1006-cat-file.sh** (31/420) — commit size/content, `--batch`
- [ ] **t1007-hash-object.sh** (17/40) — `--stdin`, `--path`, `--no-filters`

#### Sparse Checkout / Index (~36 failures)
- [ ] **t1092-sparse-checkout-compatibility.sh** (14/102)
- [ ] **t7002-mv-sparse-checkout.sh** (14/22)
- [ ] **t3903-stash.sh** (13/140)

### スコープ外

- **t1016-compatObjectFormat.sh** (181/202) — SHA-256 compat
- **t9700-perl-git.sh** — Perl Git.pm
- **t7510/t7528** — GPG/SSH 署名検証 (外部ツール依存)

### 最近の成果

- [x] **t6018-rev-list-glob.sh** — `--branches/--tags/--remotes/--glob/--all/--exclude` (2026-03-08)
- [x] **t1508-at-combinations.sh** — bare `@{N}`, reflog boundary, empty reflog (2026-03-08)
- [x] **t1503-rev-parse-verify.sh** — quiet flag, dot-separated dates (2026-03-08)
- [x] **t6302-for-each-ref-filter.sh** — `contents:lines=N` signature exclusion (2026-03-08)
- [x] pack-objects repack フラグ実装（2026-03-02）
- [x] t1517-outside-repo allowlist 追加（2026-03-02）
- [x] known-breakage パッチを `!BIT_PACK_OBJECTS` prereq skip 方式に統一（2026-03-02）

## P1: Relay / P2P collaboration

- [x] `bit hub serve` コマンドと relay session clone サポート（2026-02-21）
- [x] P2P collaboration: bidirectional git, broadcast, work-item sync（2026-02-21）
- [x] relay invite URL with room token（2026-02-21）
- [x] signed relay publish headers（2026-02-21）
- [x] proxied relay URL 検出修正（2026-02-24, PR #16）
- [x] `bit relay serve` を JS target で有効化（2026-02-23）
- [ ] SSH clone の JS target 対応（Issue #18）
  - [x] native-only の制約を文書化（2026-03-05）
  - [ ] HTTP smart protocol で JS 対応
    - [x] SSH URL → HTTPS smart URL 変換ユーティリティ追加（2026-03-05）
    - [x] JS clone/fetch/pull/push 経路へ適用（2026-03-05）
  - relay 経由 clone は両 target で動作済み

## P2: パフォーマンス

- [x] `bit status` index-guided walk: 1860ms → 9ms（2026-02-23, PR #11）
- [x] lazy ObjectDb loading for log/commit（2026-02-22）
- [x] single lstat() FFI で worktree_entry_meta 置換（2026-02-22）
- [x] checkout -b same commit で tree checkout スキップ（2026-02-22）
- [x] incremental MIDX と worktree stat skip（2026-02-23）
- [x] cat-file: lazy pack loading + `-t` early return (3.1x 改善, 2026-03-04)
- [ ] 大規模リポジトリでのベンチマーク継続（clone/fetch/status/log）

### pack-objects 高速化 (10-20x 遅い → 目標 2x 以内)

ベースライン (2026-03-04): E2E で 500obj bit=1970ms vs git=101ms (19.5x)
ベンチ: `bench_repack_wbtest.mbt`

#### プロファイル結果 (2026-03-04, moon bench 内部計測)

| 項目 | 115obj | 560obj | per-obj |
|------|--------|--------|---------|
| repack total | 30ms | 135ms | 0.24ms |
| zlib round-trip | 14ms* | 75ms | 0.13ms |
| SHA-1 | 0.6ms* | 2.9ms | 0.005ms |

(*115obj は 560obj からの按分推定)

- **zlib が全体の 55%** を占める（純粋MoonBit実装 `mizchi/zlib`）
- SHA-1 はわずか 2%（skip_hash は効果なし）
- E2E の 19.5x 差の大半は **MoonBit ランタイム起動 ~150ms** + zlib 速度差
- スケーリングは **線形 O(n)**（O(n²) 問題なし）

#### P2-0: zlib C FFI 化 → 不採用

- pure MoonBit で動くことの方が価値が高いため、C FFI 化はしない

#### P2-A: メモリ効率 (検証済み・効果なし)

- [x] **result Array[Byte] の事前容量確保** → 効果なし (2026-03-04)
  - 115obj で測定誤差内。配列再確保コストは小さい
- [x] **delta 結果の Bytes 変換コスト削減** → 効果なし (2026-03-04)
  - ボトルネックは Bytes 変換ではなく zlib

#### P2-B: 圧縮の無駄削減 (安全・小効果)

- [x] **zlib 二重圧縮の排除** → 既に「quick upper bound」最適化あり (packfile.mbt:398-423)
  - デルタが raw 未圧縮サイズより小さければ raw 圧縮をスキップ

- [ ] **RefDelta base SHA-1 キャッシュ**
  - `packfile.mbt:412,440`: `hash_object_content` を毎回再計算
  - 改善: PackObject.id を使う（SHA-1 全体の 2% なので低優先）

#### P2-C: デルタ検索の改善 (品質向上・速度は副次的)

- [ ] **オブジェクトのソート (type + size desc)**
  - 現状: stdin 順序のまま処理
  - git: type → size desc でソートし類似オブジェクトを隣接配置
  - デルタ効率が向上し出力パックが小さくなる

- [ ] **スライディングウィンドウ (--window)**
  - 現状: `last_by_type[key]` で同型の直前 1 オブジェクトのみ
  - git: window=10 で直近 10 オブジェクトを候補に
  - 改善: `Map[Int, Array[(Int, PackObject)]]` で最大 window 個保持

#### P2-D: デルタアルゴリズム改善 (効果中・慎重に)

- [ ] **build_delta のブロックインデックス再利用**
  - スライディングウィンドウで同じ base を複数 target に使う場合にキャッシュ

- [ ] **find_best_match の候補数制限緩和**
  - 現状: `checked > 64` で打ち切り → 128-256 に拡張

## P3: Git互換の残タスク

### allowlist 残り

- t0: t0012, t0450（動的 `-h` テスト生成、shim コマンドの出力不一致でパッチ困難）
- t4: t4137（apply submodule: replace submodule with file の安全チェック未実装、4/28 failures）
- t7: t7450（test-tool submodule 依存、対応困難）
- t9: svn/cvs/p4 は明示的にサポート外
  - t9001/t9210/t9211: send-email/scalar — 未対応

### その他

- [x] `--unpack-unreachable` の実装（2026-03-03, v0.26.3）
  - t7700 テスト 20/25 の `!BIT_PACK_OBJECTS` prereq skip パッチ削除（`--filter` 実装済み）
  - [x] `--unpack-unreachable=<date>` の mtime チェック（2026-03-03）
- [ ] `--help` 移植: 外部 help テキスト実体の整備（必要コマンド分）
  - [x] spec 駆動化 / 回帰テスト / オプトイン外部読込 / shim fallback 判定（完了済み）

## P3.5: realgit 委譲の削減

方針: CI SHIM_STRICT=1 で bit に通すコマンドを段階的に増やす。
CI SHIM_CMDS: 53 コマンド全て有効化済み (2026-03-03, SHIM_STRICT=1)
CI 全 906 テストパス済み。以下は未実装コマンドの新規実装候補。

### Step 1: 実装済みコマンドを CI SHIM_CMDS に追加（テスト頻度順）

各コマンドを追加 → CI で壊れるテスト特定 → 修正 → マージ の繰り返し。

#### Tier 1: 超高頻度（1000+ 呼出、テスト基盤コマンド）
- [ ] `rev-parse` (3792)
- [ ] `checkout` (3765)
- [ ] `commit` (3596)
- [ ] `add` (3268)
- [ ] `config` (2626)
- [ ] `reset` (1923)
- [ ] `branch` (1749)
- [ ] `init` (1667)
- [ ] `tag` (1199)
- [ ] `diff` (1196)
- [ ] `log` (1173)
- [ ] `ls-files` (1162)

#### Tier 2: 高頻度（400–999 呼出）
- [ ] `rebase` (991)
- [ ] `clone` (953)
- [ ] `cat-file` (921)
- [ ] `merge` (889)
- [ ] `update-ref` (824)
- [ ] `hash-object` (614)
- [ ] `status` (608)
- [ ] `submodule` (603)
- [ ] `notes` (600)
- [ ] `push` (534)
- [ ] `mv` (488)
- [ ] `stash` (472)
- [ ] `rm` (470)
- [ ] `fetch` (461)
- [ ] `worktree` (421)
- [ ] `bisect` (420)

#### Tier 3: 中頻度（100–399 呼出）
- [ ] `show` (362)
- [ ] `symbolic-ref` (335)
- [ ] `cherry-pick` (324)
- [ ] `grep` (312)
- [ ] `format-patch` (300)
- [ ] `remote` (298)
- [ ] `reflog` (296)
- [ ] `switch` (251)
- [ ] `pull` (250)
- [ ] `show-ref` (239)
- [ ] `clean` (232)
- [ ] `diff-index` (219)
- [ ] `ls-tree` (180)
- [ ] `diff-files` (170)
- [ ] `write-tree` (147)
- [ ] `sparse-checkout` (113)
- [ ] `blame` (110)

#### Tier 4: 低頻度（<100 呼出）
- [ ] `revert` (82)
- [ ] `gc` (81)
- [ ] `shortlog` (53)
- [ ] `describe` (53)

### Step 2: 未実装コマンドの新規実装（テスト頻度順）

full mode にも含まれない高頻度 plumbing / porcelain。

- [ ] `update-index` (720) — plumbing: index 直接操作
- [ ] `rev-list` (521) — plumbing: コミット列挙
- [ ] `apply` (398) — パッチ適用
- [ ] `repack` (302) — 内部で pack-objects 呼出
- [ ] `am` (235) — apply + commit
- [ ] `for-each-ref` (234) — ref 列挙 (format 出力)
- [ ] `diff-tree` (224) — plumbing: tree 間 diff
- [ ] `fast-import` (196) — bulk import
- [ ] `read-tree` (176) — plumbing: tree → index
- [ ] `fsck` (159) — 整合性チェック
- [ ] `commit-graph` (137) — commit-graph 管理
- [ ] `archive` (135) — アーカイブ生成
- [ ] `multi-pack-index` (133) — MIDX 管理
- [ ] `ls-remote` (127) — リモート ref 列挙
- [ ] `restore` (117) — worktree/index 復元
- [ ] `commit-tree` (114) — plumbing: commit 生成
- [ ] `bundle` (110) — bundle 作成/検証
- [ ] `stripspace` (108) — テキスト整形
- [ ] `checkout-index` (108) — plumbing: index → worktree

### 作業手順

1. 対象コマンドを CI SHIM_CMDS に追加するブランチを作成
2. CI を回して失敗テストを特定
3. bit 実装の修正 or `!BIT_<CMD>` prereq skip パッチで対応
4. `just release-check` → CI 通過を確認
5. マージ後、次のコマンドへ

## P4: WASM / クロスプラットフォーム

- [x] WASM Component Model ビルド追加（2026-02-22）
- [x] clone/fetch/push ネットワークオペレーションの WASM Component 実装（2026-02-22）
- [x] cross-platform crypto パッケージ抽出（2026-02-22）
- [ ] WASM target での機能カバレッジ拡大
- [ ] JS target の SSH clone 代替（HTTP smart protocol 検討）→ Issue #18

## P5: プラットフォーム/将来タスク

- [x] `~/.config/bit/bitconfig.toml` config ファイルサポート（2026-02-23）
- [x] `bit hub` → `bit pr`/`bit issue`/`bit debug` 再編（2026-02-23）
- [x] `bit hooks` 管理と safe execution（2026-02-17）
- [x] hook approval flow: `.bit/hooks` ↔ `.git/hooks`（2026-02-17）
- [x] `bit hub issue watch` daemon with WebSocket/poll fallback（2026-02-23）
- [x] AI コマンドスイート整備（rebase-ai 連携, 2026-02-18）
- [x] `x/doc` コマンド追加（2026-02-20）
- [x] SSH clone: native interactive protocol 実装（2026-02-24, PR #17）
- [ ] Moonix integration: ToolEnvironment <-> AgentRuntime（moonix release 待ち）
- [ ] bit mount: ファイルシステムにマウントする機能
- [ ] bit mcp: MCP 対応
- [ ] BIT~ 環境変数の対応
- [ ] `.bitignore` 対応
- [ ] `.bit` 対応（`.git` → `.bit` ディレクトリ切替）
- [ ] bit jj: jj 相当の対応
