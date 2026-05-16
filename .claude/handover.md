# Blueprint-Flow セッション引き継ぎ

> 作成: 2026-05-16 / 改訂: 2026-05-16 (3 回目: Review Scoring Rubric 追加)
> 状態: 設計合意完了・実装未着手

## このセッションで何をしたか

1. **Anthropic 公式 blog の 3 ヶ月分スクレイピング**を `~/claude/scripts/anthropic-blog-digest/` に構築（launchd 月・金 09:00 自動実行）
   - 出力: `~/claude/memory.db` `tips` (`project='anthropic-blog'`、38 件)
   - Top10 Notion: https://www.notion.so/3623c593ca5681178cfec176001427ab

2. **"Building Effective AI Agents" を基準に /bpf をサブエージェントレビュー**
   - 5 件の修正提案 (#1..#5)

3. **「プロト→MVP→β→製品版」ステージモデルの設計合意**（v3 設計）
   - 第 1 版: stage 軸 + クローン進化 + 4 点人間レビュー
   - 第 2 版: stage を **UX 完成度 %** (25/50/75/100) に再定位、perf/sec は post-V1、Wave 計画導入
   - **第 3 版（最終）**: **Review Scoring Rubric** 導入、bpf 閾値 75 / night-runner 閾値 95、night-runner に dirty queue

## 最重要参照ファイル

| パス | 役割 |
|---|---|
| **`/Users/a_t/.blueprint-flow/BLUEPRINT_FLOW_v3.md`** | **唯一の真実の仕様書**（最終版・16 章・約 880 行）|
| `/Users/a_t/.blueprint-flow/BLUEPRINT_FLOW_v2.md` | 旧仕様（履歴）|
| `/Users/a_t/.blueprint-flow/.claude/CLAUDE.md` | Chrome 拡張スタック用プロジェクト指示 |
| `~/claude/scripts/anthropic-blog-digest/README.md` | digest スクリプト実装 |

Notion ページ:
- 親: 「Yakaze Tech Studio」 (id: `2223c593-ca56-80ab-b4d7-f6cf2ce24141`)
- Anthropic Blog Top10: https://www.notion.so/3623c593ca5681178cfec176001427ab
- **Blueprint-Flow v3 設計**: https://www.notion.so/3623c593ca5681989c64f0e46127fcbd

## v3 で確定した決定事項

### Stage モデル（UX 完成度軸）

- `step_status` 4 段 (`define→impl→test→done`)
- `cores.stage = proto/mvp/beta/prod/prod_reviewed`（UX 25/50/75/100%）
- 25/50/75/100% の具体は **プロジェクト固有**: `cores.overview.content` の `## UX Rubric` 節
- 共通テンプレ: `rules/stages.md`
- パフォーマンス・本格セキュリティ・E2E は **post-V1 行き**
- Universal Minimum Bars（全 stage 共通）: 認証 / XSS/CSRF/SQLi 基本ガード / secrets 管理 / 明らかなバグ排除

### クローン進化

- stage 切替時に blueprint をクローン、前 stage は `frozen=1` で履歴保存
- default 検索は `active_blueprints` view 経由
- content 自動書き換えなし（sync_content 撤去）

### **Review Scoring Rubric（v3 改訂で新設）**

「LLM がブレずに判断する」ための 0-100 スコア体系。

**失敗モード MECE 軸 (4)**:
- L (Loss) / K (Lock-in) / D (Drift) / G (Gate)

**Score=100（MANDATORY、MECE 閉リスト）**:
1. F1: Production / public / shared-state 操作 (L+K)
2. F2: Stage gate 発火 (G)
3. F3a: Spec gap on contract surface (D)
4. F4a: Security boundary 新設・変更 (L+K)

**主要 Floor**:

| Floor | Trigger | Score |
|---|---|---|
| F1 | 本番/公開/共有状態 | 100 |
| F2 | Stage gate | 100 |
| F3a | Spec gap (contract 面) | 100 |
| F4a | Security boundary | 100 |
| F5 | Schema migration | 85 |
| F7 | Test 削除/弱化 | 85 |
| F8 | LLM confidence <50% | 80 |
| F6 | 新依存追加 | 75 |
| F10 | Off-spec 変更 | 70 |
| default | 通常実装 | 30 |

**閾値**:
- **bpf**: ≥ 75 → block + AskUserQuestion
- **night-runner**: ≥ 95 → block + Slack、75-94 → **dirty queue**

**Anti-drift 装置**:
1. LLM は連続スコア推定しない（Yes/No 判定のみ）
2. 構造化 JSON 強制 (`{score, trigger, mode, decision, reason}`)
3. 複数 fire → MAX (加算しない)
4. 迷ったら conservative default (score=80, ask)
5. `trigger` は closed enum (`F1`..`F11` / `default` / `cleanup` / `mechanical` / `uncertain`)
6. **各 floor に positive + negative 例を 3 件以上ずつ** `rules/review-rubric.md` に列挙（境界を両側から定義）

### 人間レビュー

- bpf 閾値 75 以上で block → AskUserQuestion / `bpf stage review`
- night-runner 閾値 95 以上で block → Slack alert
- night-runner で 75-94 の決定は `review_decisions` に `outcome='queued'` で記録
- 人間は次セッションで `bpf review queue` で一括確認、必要なら retro-approve/reject

### bpf スコープ

- `prod_reviewed` で bpf 終端
- E2E テスト・スクショ・動画・マニュアル・本格 perf/sec 監査は **別ワークフロー**

### 新規 DB テーブル: `review_decisions`

- act 毎・stage gate 毎の rubric 判定を全部記録
- Wave 3 の evaluator 分離判断のデータソース兼用
- `runner` 列で bpf / night-runner を区別

## Wave 計画

| Wave | 内容 | タイミング |
|---|---|---|
| **Wave 1** | v3 stage モデル + #3 sync_content 撤去 + #5 knowledge_sets 撤去 + **rubric 統合** | 次セッション着手 |
| **Wave 2** | #4 bin/bpf 分離（純 DX） | Wave 1 安定後、任意 |
| **Wave 3** | #2 evaluator agent 分離（`review_decisions` データで誤判定率測定後）| Wave 1 後 1-2 週間データ収集 → 判断 |

### Wave 1 内の段階

- **1a (additive migration)**: 新カラム / view / table 追加（**`review_decisions` 含む**）
- **1b (hub.py refactor)**: SELECT → view 経由、stage コマンド、sync_content 撤去、knowledge_sets dict 化、**rubric threshold gate**
- **1c (cleanup)**: test_level / knowledge_sets drop

## 次セッションで取り組む選択肢

### A. Wave 1 全部実装着手（推奨）

v3.md §15「実装着手手順」+ §16「Wave 計画詳細」に従って:

1. `bpf db migrate-v3` 実装（schema 全部 + **`review_decisions` テーブル**）
2. hub.py refactor（SELECT view 化、stage コマンド、**`hub.py review` コマンド**、sync_content 撤去、knowledge_sets dict 化、**rubric threshold gate**）
3. cleanup drop
4. **`rules/review-rubric.md` 新規作成**（§9 ベース）。**各 floor に positive 例（fire する）と negative 例（fire しない／紛らわしいが該当外）を最低 3 件ずつ**並べる — anti-drift の核。Anthropic 風に言えば examples が LLM の judgment を anchor する唯一の手段。positive だけだと境界が曖昧になり、LLM が「迷ったら fire」に振れる（保守バイアス）か「迷ったら skip」に振れる（過信バイアス）かのどちらかに drift する。
5. `rules/stages.md` 新規作成
6. `bpf init` overview テンプレに `## UX Rubric` 雛形
7. `agents/coding.md` を rubric JSON emit + stage 認識 + UX Rubric ロード仕様に
8. `skills/bpf/SKILL.md` 閾値 75 / `skills/night-runner/SKILL.md` 閾値 95・dirty queue

### B. Wave 1a サブセットから（リスク最小化）

加算的 migration だけ先にやって動作確認、その後 1b / 1c へ。

### C. v3 dogfooding（blueprint-flow 自体に /bpf を回す）

Wave 1 実装中・直後に、blueprint-flow 自身に proto stage から /bpf を適用。Wave 3 用 `review_decisions` データ収集も兼ねる。

## v3.md の改訂履歴

| 改訂 | 内容 |
|---|---|
| 第 1 版 | stage 軸 + クローン進化 + 4 点人間レビュー |
| 第 2 版 | UX% リフレーム + perf/sec を post-V1 へ + Wave 計画 |
| **第 3 版（最終）** | **Review Scoring Rubric 新設**（§9）+ `review_decisions` テーブル + 閾値 75/95 + night-runner dirty queue |

**v3.md を読むのは最終版**。各章は最終版に上書き済み。

## 未確定の論点

- Slack 通知先（既存 webhook vs 専用チャンネル）
- `bpf stage review` / `bpf review queue` UI（CLI vs Web UI）
- クローン時 content 書き換えオプション
- post-prod ツール名・置き場所
- `bpf init` で `## UX Rubric` 雛形を自動挿入するか
- `bpf doctor` (sync_content 代替) の v3.x 導入可否
- **rubric の F3a/F4a 境界の運用線引き**（実運用で振れたら調整）
- **rubric 閾値 75/95** の調整（dirty queue 規模を 1 ヶ月運用後に見直し）

## 注意

- このセッションで /bpf 本体には **コード変更を加えていない**。v3.md は仕様書のみ
- Anthropic digest スクリプトは launchd 登録済み・自動運行中。次回 2026-05-18 (月) 09:00
- ユーザーは日本語で対話する
- ユーザーは「コーディング原則」（CLAUDE.md / docs/coding-principles.md）に従った実装を望む

## 再開時の最初の 3 ステップ

1. `cat /Users/a_t/.blueprint-flow/BLUEPRINT_FLOW_v3.md` を **必ず全部** 読む（16 章）
2. ユーザーに「Wave 1 全部 (A) / Wave 1a サブセット (B) / dogfooding 併用 (C)」を AskUserQuestion で確認
3. v3.md §15 + §16 に沿って TaskCreate で task 分解 → 着手
