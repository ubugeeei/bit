# Completed Tasks

完了済みタスクのアーカイブ。TODO.md から移動。

## Git compatibility (P0)

### テスト修正

- [x] **t6101-rev-parse-parents.sh** — `^@`, `^!`, `^-`, `..`, `...`, `^` negation (2026-03-09)
- [x] **t6002-rev-list-bisect.sh** — `--bisect` default refs (2026-03-08)
- [x] **t1350-config-hooks-path.sh** — `core.hooksPath` support (2026-03-08)
- [x] **t3300-funny-names.sh** — ls-tree C-quoting (2026-03-08)
- [x] **t6018-rev-list-glob.sh** — `--branches/--tags/--remotes/--glob/--all/--exclude` (2026-03-08)
- [x] **t1508-at-combinations.sh** — bare `@{N}`, reflog boundary, empty reflog (2026-03-08)
- [x] **t1503-rev-parse-verify.sh** — quiet flag, dot-separated dates (2026-03-08)
- [x] **t6302-for-each-ref-filter.sh** — `contents:lines=N` signature exclusion (2026-03-08)
- [x] pack-objects repack フラグ実装（2026-03-02）
- [x] t1517-outside-repo allowlist 追加（2026-03-02）
- [x] known-breakage パッチを `!BIT_PACK_OBJECTS` prereq skip 方式に統一（2026-03-02）

### pack-objects / repack

- [x] `--unpack-unreachable` の実装（2026-03-03, v0.26.3）
  - t7700 テスト 20/25 の `!BIT_PACK_OBJECTS` prereq skip パッチ削除（`--filter` 実装済み）
  - `--unpack-unreachable=<date>` の mtime チェック（2026-03-03）
- [x] `--help` spec 駆動化 / 回帰テスト / オプトイン外部読込 / shim fallback 判定

### pack-objects 高速化調査

- [x] result Array[Byte] の事前容量確保 → 効果なし (2026-03-04)
- [x] delta 結果の Bytes 変換コスト削減 → 効果なし (2026-03-04)
- [x] zlib 二重圧縮の排除 → 既に「quick upper bound」最適化あり
- [x] zlib C FFI 化 → 不採用（pure MoonBit の方が価値が高い）

## Relay / P2P collaboration (P1)

- [x] `bit hub serve` コマンドと relay session clone サポート（2026-02-21）
- [x] P2P collaboration: bidirectional git, broadcast, work-item sync（2026-02-21）
- [x] relay invite URL with room token（2026-02-21）
- [x] signed relay publish headers（2026-02-21）
- [x] proxied relay URL 検出修正（2026-02-24, PR #16）
- [x] `bit relay serve` を JS target で有効化（2026-02-23）
- [x] SSH clone JS target: native-only の制約を文書化（2026-03-05）
- [x] SSH URL → HTTPS smart URL 変換ユーティリティ追加（2026-03-05）
- [x] JS clone/fetch/pull/push 経路へ適用（2026-03-05）

## パフォーマンス (P2)

- [x] `bit status` index-guided walk: 1860ms → 9ms（2026-02-23, PR #11）
- [x] lazy ObjectDb loading for log/commit（2026-02-22）
- [x] single lstat() FFI で worktree_entry_meta 置換（2026-02-22）
- [x] checkout -b same commit で tree checkout スキップ（2026-02-22）
- [x] incremental MIDX と worktree stat skip（2026-02-23）
- [x] cat-file: lazy pack loading + `-t` early return (3.1x 改善, 2026-03-04)

## WASM / クロスプラットフォーム (P4)

- [x] WASM Component Model ビルド追加（2026-02-22）
- [x] clone/fetch/push ネットワークオペレーションの WASM Component 実装（2026-02-22）
- [x] cross-platform crypto パッケージ抽出（2026-02-22）

## プラットフォーム/将来タスク (P5)

- [x] `~/.config/bit/bitconfig.toml` config ファイルサポート（2026-02-23）
- [x] `bit hub` → `bit pr`/`bit issue`/`bit debug` 再編（2026-02-23）
- [x] `bit hooks` 管理と safe execution（2026-02-17）
- [x] hook approval flow: `.bit/hooks` ↔ `.git/hooks`（2026-02-17）
- [x] `bit hub issue watch` daemon with WebSocket/poll fallback（2026-02-23）
- [x] AI コマンドスイート整備（rebase-ai 連携, 2026-02-18）
- [x] `x/doc` コマンド追加（2026-02-20）
- [x] SSH clone: native interactive protocol 実装（2026-02-24, PR #17）
