# Blueprint-Flow v3

> Document-driven development framework — **UX 完成度ステージモデル** + clone-based blueprint progression + **Review Scoring Rubric**.
> v2 (2026-02) からの後継版。決定日: 2026-05-16。改訂履歴:
> - 2026-05-16: 初版（stage 軸 + クローン進化 + 4 点人間レビュー）
> - 2026-05-16: UX% リフレーム + Wave 計画統合
> - 2026-05-16: **Review Scoring Rubric** 追加（bpf 閾値 75 / night-runner 閾値 95）

---

## 0. このドキュメントの位置づけ

- v3 は **唯一の真実の仕様書**。v2 (`BLUEPRINT_FLOW_v2.md`) は履歴として残すが、矛盾した場合は v3 を優先。
- v3 は「実装前の設計合意」を凍結したものであり、これ自体がまだコードに落ちていない部分を含む。
- 参考: Anthropic "Building Effective AI Agents" (https://www.anthropic.com/engineering/building-effective-agents) の用語・原則に準拠して設計した。

---

## 1. なぜ v3 か（動機）

v2 設計には 3 つの不整合があった:

### 1.1 v2 の `test_l1 / test_l2 / test_l3` グローバルゲートの問題

v2 では blueprint 毎の `step_status` が 6 段で、しかも「全 blueprint の test_l1 完了まで test_l2 ブロック」グローバルゲートがあった。並列性を直接潰すので撤廃。

### 1.2 「成熟度ステージ」を UX 完成度軸で明示したい

プロトタイプ → MVP → β → 製品版 の 4 段を **UX 完成度 25/50/75/100%** の比例軸として一元化。パフォーマンス・本格セキュリティは post-V1 行き（§3.6）。

### 1.3 人間レビュー基準を **ブレないスコアルーブリック** に統一したい

v2 では「いつ人間に聞くか」がエージェントの主観任せで、night-runner / bpf で挙動が一貫しなかった。v3 では **失敗モード MECE 軸 + Floor 表 + 固定スコア** で LLM が判定する仕組みを導入（§9）。bpf 閾値 ≥75 / night-runner 閾値 ≥95。

### 1.4 Anthropic 記事との整合

- workflow vs agent: /bpf は workflow（決定的 step machine + LLM 実装）
- 5 パターン: prompt chaining (中核) / orchestrator-workers / evaluator-optimizer / parallelization (sectioning) / routing (実質未使用)
- 設計原則: "add complexity only when it demonstrably improves outcomes" / "transparency"

---

## 2. v2 から v3 への変更サマリ

| 領域 | v2 | v3 |
|---|---|---|
| Blueprint 内 step | 6 段 (`test_l1/l2/l3` 含む) | **4 段** (`define→impl→test→done`) |
| グローバルゲート | test_l*  blueprint 横断 | **撤廃**、並列性最大化 |
| プロジェクト成熟度 | 概念なし | **UX 完成度 % 軸** (`cores.stage`) |
| Blueprint 進化 | 破壊的更新 | **クローン進化** (前 stage は `frozen=1` で永続保存) |
| 検索 view | 単一 | **`active_blueprints`** (現 stage + frozen=0) |
| 人間レビュー判定 | 主観・stage 境界のみ | **Review Scoring Rubric** で 0-100 スコア化、閾値で自動判定 |
| `bpf` レビュー閾値 | 概念なし | **≥ 75** (block + AskUserQuestion) |
| `night-runner` レビュー閾値 | 自己申告 ✓ パース | **≥ 95** (block + Slack)、75-94 は **dirty queue** へ |
| パフォーマンス・本格セキュリティ | stage 毎に分解 | **post-V1 行き** (Universal Minimum Bars のみ stage 内で守る) |
| Post-prod (E2E/マニュアル) | bpf 内 | **bpf スコープ外** (別ワークフロー) |
| `sync_content` 自動 spec 書き換え | デフォルト有効 | **撤去** (Wave 1、v3 のクローンモデルが代替) |
| `knowledge_sets` テーブル | 存在 | **撤去** (Wave 1、Python dict 化) |
| `bin/bpf` の scaffolding | 同居 | **`bpf-new` に分離** (Wave 2、任意) |
| Evaluator-Generator 分離 | なし | `review_decisions` で集めたデータで Wave 3 判断 |

---

## 3. 中核概念

### 3.1 Augmented LLM

- **retrieval**: `hub.py` 経由で `blueprint.db` から関連 row を取得
- **tools**: `hub.py` CLI + Bash 等
- **memory**: `blueprint.db` 自体が共有の長期メモリ

### 3.2 Workflow vs Agent

**/bpf は workflow**: step 遷移はハードコード、LLM は各 step 内の実装を自律判断。動的に「次の step」を決めない。

### 3.3 Stage モデル（UX 完成度軸）

```
proto (25%) → mvp (50%) → beta (75%) → prod (100%) → prod_reviewed
                                                          ↑
                                                          bpf スコープ終端
```

stage は UX 完成度の % 軸。25/50/75/100% の具体は **プロジェクト固有** (`cores.overview.content` の `## UX Rubric` 節)。

### 3.4 Blueprint クローン進化

stage advance 時:
1. 現 stage の全 blueprint を `frozen=1` に
2. 新 stage 用に **クローン**（新 row、`parent_blueprint_id` で履歴 link）
3. クローンの `content` は前 stage のコピー（人間 / 明示 LLM コールで書き換え）
4. `step_status` は `'define'` で開始

content の **自動書き換えなし**（sync_content 撤去）。

### 3.5 default 検索

`hub.py` の SELECT は `active_blueprints` view 経由（`frozen=0 AND b.stage = cores.stage`）。

### 3.6 Universal Minimum Bars

stage 軸とは**直交する別軸**、proto から全 stage で守る:

- 認証・認可（粗くて OK、コア機能のみ）
- XSS / CSRF / SQLi の**フレームワーク標準ガード**有効化
- secrets を git にコミットしない
- 明らかなクラッシュ・無限ループの排除

本格セキュリティ監査・パフォーマンス最適化・スケール対応は **post-V1 行き**。

### 3.7 Review Scoring Rubric（§9 の概念）

「人間に聞くべきか」を **LLM がブレずに判定**するための 0-100 スコア体系。失敗モード MECE 軸 + Floor 表 + 固定スコア + MAX 集約。詳細は §9。

---

## 4. データベーススキーマ

### 4.1 cores

```sql
CREATE TABLE cores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,                         -- overview / config / tech
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    summary TEXT NOT NULL,
    content TEXT NOT NULL,                      -- overview の場合 "## UX Rubric" 節を含む
    reviewed BOOLEAN DEFAULT 0,
    stage TEXT NOT NULL DEFAULT 'proto'
        CHECK(stage IN ('proto','mvp','beta','prod','prod_reviewed')),
    stage_dirty INTEGER NOT NULL DEFAULT 0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 4.2 blueprints

```sql
CREATE TABLE blueprints (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    slug TEXT NOT NULL, name TEXT NOT NULL, summary TEXT NOT NULL,
    content TEXT NOT NULL,
    step_status TEXT NOT NULL DEFAULT 'define'
        CHECK(step_status IN ('define','impl','test','done')),
    stage TEXT NOT NULL DEFAULT 'proto'
        CHECK(stage IN ('proto','mvp','beta','prod')),
    parent_blueprint_id INTEGER REFERENCES blueprints(id),
    frozen INTEGER NOT NULL DEFAULT 0,
    reviewed BOOLEAN DEFAULT 0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(stage, slug, frozen)
);
```

### 4.3 active_blueprints view

```sql
CREATE VIEW active_blueprints AS
  SELECT b.* FROM blueprints b
  JOIN cores c ON c.type = 'overview'
  WHERE b.stage = c.stage AND b.frozen = 0;
```

### 4.4 stage_transitions

```sql
CREATE TABLE stage_transitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    core_id INTEGER NOT NULL REFERENCES cores(id),
    from_stage TEXT NOT NULL, to_stage TEXT NOT NULL,
    reviewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);
```

### 4.5 review_decisions（**Wave 1 で追加**・rubric の監査ログ）

```sql
CREATE TABLE review_decisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    act_id INTEGER, blueprint_id INTEGER,
    runner TEXT NOT NULL,                      -- 'bpf' / 'night-runner'
    decision_type TEXT NOT NULL,               -- 'pre_action' / 'post_complete' / 'stage_gate'
    trigger TEXT NOT NULL,                     -- 'F1'..'F11' / 'default' / 'cleanup' / 'mechanical'
    mode TEXT,                                 -- 'L' / 'K' / 'D' / 'G' (failure mode)
    score INTEGER NOT NULL,
    threshold INTEGER NOT NULL,                -- 75 (bpf) / 95 (night-runner)
    asked_human INTEGER NOT NULL,              -- 0/1
    outcome TEXT NOT NULL,                     -- 'approved' / 'rejected' / 'skipped' / 'queued'
    reason TEXT NOT NULL,
    raw_emit TEXT,                             -- LLM の元 JSON
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_review_decisions_act ON review_decisions(act_id);
CREATE INDEX idx_review_decisions_runner_score ON review_decisions(runner, score);
```

このテーブルは **Wave 3 (evaluator 分離判断) のデータソース**も兼ねる。

### 4.6 v3 で削除されるもの (Wave 1c)

- `blueprints.test_level` カラム
- `knowledge_sets` テーブル（Python dict 化、§12-#5）

---

## 5. ステージ詳細

### 5.1 各ステージの達成ライン（UX 完成度軸）

| Stage | UX% | 意味（プロジェクト固有 rubric で具体化） | unit/feature テスト * |
|---|---|---|---|
| **proto** | **25%** | 動くプロトタイプ・コンセプト検証可能 | smoke test 1 件 / blueprint |
| **mvp** | **50%** | 主要 happy path 完走・タスク完了可能 | happy + 重要 edge 1 件 |
| **beta** | **75%** | 初期ユーザーに見せられる磨き・頻出 edge 対応 | happy + edges |
| **prod** | **100%** | 市場競争力ある v1.0 リリース可能 | unit + feature フル（**E2E 除く**） |
| **prod_reviewed** | — | bpf 終端 | — |
| (post-V1, bpf 外) | — | パフォーマンス・スケール・高度セキュリティ・E2E・マニュアル | E2E フル |

\* テストは Universal Minimum Bars 上の追加分。

### 5.2 プロジェクト固有性

- 共通テンプレ: `rules/stages.md`
- プロジェクト固有: `cores.overview.content` の **`## UX Rubric`** 節（プロジェクト毎の 25/50/75/100% 具体定義）

### 5.3 TDD

`step_status='impl'` 遷移時に対応 test の存在を `hub.py` がガード。E2E は bpf 内では書かない。

### 5.4 stage_dirty 自動検知

```python
def cmd_complete(act_id):
    # ... 既存 ...
    if all_active_blueprints_done(core_id):
        db.execute("UPDATE cores SET stage_dirty=1 WHERE id=?", (core_id,))
        post_slack(f"🎯 {project} {current_stage} 完了 (UX {pct}% 達成見込み) — `bpf stage review`")
        # rubric 上は F2 (Gate) score=100、threshold 関係なく ask
        log_review_decision(core_id, trigger='F2', mode='G', score=100, ...)
```

---

## 6. コマンド体系（bpf）

### 6.1 既存（変更なし）

```
bpf init [--stack <name>] / bpf update / bpf db init|reset|seed
bpf home / bpf ui / bpf next / bpf complete <act_id>
```

### 6.2 v3 で追加

```
bpf stage                                 # 現 stage 表示
bpf stage status                          # n/m blueprints done + UX% 推計
bpf stage review                          # 人間 review 入力モード (差分 + approve/reject)
bpf stage advance                         # 次 stage へ
bpf blueprint refine <id> --to-stage <s>  # (任意) クローン後 content を LLM で書き換え
bpf blueprints --include-frozen [--stage <s>]
bpf db migrate-v3                         # v2 → v3 一括移行

# v3 改訂版で追加 (rubric 関連):
bpf review queue                          # night-runner が貯めた dirty queue を一覧
bpf review queue --decide <id>            # queue 内の特定決定にレトロでレビュー入力
bpf review log [--score-min N] [--trigger F5]
                                          # review_decisions 監査表を SQL で参照
```

### 6.3 `bpf stage advance` 擬似コード

§14.2 参照（既存と同じ）。

---

## 7. Agent 連携

### 7.1 Hub

- `hub.py next/get` の応答に `current_stage` + UX Rubric 抜粋 + rubric 出力フォーマット指示 を含める
- `cmd_complete` 末尾に stage_dirty 検知 + Slack
- SELECT を `active_blueprints` view 経由化
- 新コマンド: `hub.py stage <subcommand>` / `hub.py review <subcommand>`
- 各 act execution 前後で coding agent が emit した `{score, trigger, ...}` を `review_decisions` に記録、閾値判定して block / queue

### 7.2 Coding Agent

`.claude.*/agents/coding.md` を更新:

- 起動時に `cores.stage` + `rules/stages.md` + プロジェクトの `## UX Rubric` + **`rules/review-rubric.md`** をロード
- 重要操作の前に必ず **rubric JSON を emit**（§9.4 のスキーマ）
- 実装スコープは UX% で絞る、E2E 書かない、Universal Minimum Bars は proto から守る

### 7.3 Night-Runner

- bpf と同じ rubric を使うが **threshold = 95**
- 75-94 の決定は `review_decisions` に `outcome='queued'` で記録、人間判定を待たず実装続行
- score ≥ 95 で停止 + Slack alert（人間が見るまで待つ）
- 人間は次セッションで `bpf review queue` で一括確認

### 7.4 Evaluator（Wave 3）

`review_decisions` の蓄積データを使って:
- 自己申告 ✓ で skip 判定だったものに後追い修正が入った率 → 誤判定率
- 誤判定率 > 10% なら evaluator agent 分離を実装

---

## 8. テスト方針

### 8.1 何を書く・何を書かない

- 書く: unit / feature テスト。stage 別に量を絞る（§5.1）
- 書かない（bpf 内）: E2E
- TDD: test を impl の前に書く。`step_status='impl'` 遷移時に test 存在を hub.py がガード

### 8.2 人間レビューの位置づけ（**v3 改訂後**）

人間レビューは **§9 Review Scoring Rubric** によって自動判定される。代表的な人間介在点:

| 種類 | スコア | bpf 挙動 | night-runner 挙動 |
|---|---|---|---|
| **Stage gate** (F2) | 100 | block → `bpf stage review` | block → Slack alert |
| **Production / public op** (F1) | 100 | block → ask | block → Slack alert |
| **Spec gap** (F3a) | 100 | block → ask | block → Slack alert |
| **Security boundary** (F4a) | 100 | block → ask | block → Slack alert |
| **Schema migration** (F5) | 85 | block → ask | dirty queue へ |
| **新依存追加** (F6) | 75 | block → ask | dirty queue へ |
| **Off-spec 変更** (F10) | 70 | 静かに進行 | dirty queue へ |
| 通常実装 (default) | 30 | 静かに進行 | 静かに進行 |
| Cleanup | 5 | 静かに進行（記録もしない）| 同上 |

v3 初版では "stage 境界 4 点のみ" としていたが、改訂版では **stage 境界 = F2/F3a/F4a/F1 の score=100 ケース**として rubric に統合され、追加の中間スコアトリガーも自動で人間に上がる。

### 8.3 bpf スコープの終端

`prod_reviewed` で bpf 責務終了。post-prod は別ワークフロー（§10.3）。

---

## 9. Review Scoring Rubric（**v3 改訂で新設**）

### 9.1 設計思想

「LLM がブレずに判断する」を実現するために:

1. **LLM に連続スコアを推定させない**。スコアは Floor 表で**固定**
2. LLM の判定範囲は「**どの Floor が fire したか**」の Yes/No のみ
3. 複数 fire → **MAX を取る**（加算しない・LLM に重み推測させない）
4. 出力は **構造化 JSON 強制**（free-text 解釈の余地を消す）
5. 判定に迷ったら **conservative default**（score=80, ask）

### 9.2 失敗モード MECE 軸（4 つ）

すべての「人間に聞くべき」トリガーはこの 4 つのいずれかに帰着:

| Mode | 意味 | 代表例 |
|---|---|---|
| **L (Loss)** | 不可逆な損失（データ・信用・コード） | 本番 DB drop、main へ force push |
| **K (Lock-in)** | 将来選択肢を縛るコミット | 有料契約、公開 API、secret 漏洩 |
| **D (Drift)** | 承認済 spec から外れる行動 | spec gap、低 confidence、off-spec |
| **G (Gate)** | 事前予定の人間チェックポイント | stage advance |

### 9.3 スコア = 100（**MANDATORY**・MECE 閉リスト）

必ず人間レビューが要る。これ以外は 100 にしない。

1. **F1: Production / public-facing / shared-state 操作** (L + K)
   - 例: main へ git push、本番デプロイ、公開チャンネルへの投稿（Slack/Twitter/Email）、ドメイン購入、有料モード有効化、第三者向けの永続的コミット
2. **F2: Stage gate 発火** (G)
   - 例: `cores.stage_dirty=1`、`bpf stage advance` 要求、`prod_reviewed` 到達
3. **F3a: Spec gap on contract surface** (D)
   - 例: blueprint が定義していない仕様面の動作を LLM が発明する必要、複数 spec の矛盾
   - **NOT**: 実装詳細の選択幅（それは F3b = 70）
4. **F4a: Security boundary 新設・変更** (L + K)
   - 例: 認証フロー新設・改変、パーミッションモデル変更、secrets ローテーション、暗号化方式変更
   - **NOT**: 既存セキュリティ機構の bug fix（それは F4b = 80）

### 9.4 Floor 表（決定的スコアテーブル）

| Floor | Mode | Trigger | Score |
|---|---|---|---|
| **F1** | L+K | Production / public / shared-state 操作 | **100** |
| **F2** | G | Stage gate 発火 | **100** |
| **F3a** | D | Spec gap on contract surface | **100** |
| **F4a** | L+K | Security boundary 新設・変更 | **100** |
| F4b | L | Security 実装詳細 (hash algo, token TTL 等) | 80 |
| F5 | L | Schema migration on data-bearing table | 85 |
| F6 | K | 新規外部依存追加 (npm/composer/SaaS) | 75 |
| F7 | L | Test removed / 弱化 / xfail マーク | 85 |
| F8 | D | LLM confidence < 50% on spec interpretation | 80 |
| F9 | D | LLM confidence 50-70% | 55 |
| F10 | D | Off-spec 変更 (blueprint 外を触る) | 70 |
| F11 | D | このコードベース初出のパターン | 55 |
| F3b | D | Spec ambiguity on implementation detail | 70 |
| (default) | — | どの floor も fire しない通常実装 | **30** |
| (cleanup) | — | whitespace / comment / lint auto-fix | **5** |
| (mechanical) | — | spec から 1:1 transcribe | **15** |

### 9.5 判定アルゴリズム（LLM が実行）

```
for each Floor F:
    fire[F] = (このアクションは F のトリガーに該当するか?  Yes / No)
        ← LLM の判断はこの Yes/No のみ
fired = {F : fire[F]}
if fired is empty:
    score = (cleanup なら 5 / mechanical なら 15 / それ以外 30)
else:
    score = max(Floor.score for Floor in fired)
```

### 9.6 出力フォーマット（強制 JSON）

```json
{
  "score": 85,
  "trigger": "F5",
  "mode": "L",
  "decision": "ask_human",
  "reason": "Schema migration on existing users table (~200 rows). Drop column is irreversible without backup."
}
```

複数 floor が fire した場合は最高スコアの floor を `trigger` に記録、`also_fired` に他の floor リスト:

```json
{
  "score": 100,
  "trigger": "F1",
  "also_fired": ["F4a", "F5"],
  "mode": "L+K",
  "decision": "ask_human",
  "reason": "Deploying schema migration to production with auth model change. Three floors fired; F1 dominates."
}
```

### 9.7 閾値とモード別挙動

| モード | 閾値 | score ≥ 閾値 | score < 閾値 |
|---|---|---|---|
| **bpf** (interactive) | **≥ 75** | block → AskUserQuestion (or `bpf stage review` for F2) | 静かに進行、`review_decisions` 記録 (≥30 のみ) |
| **night-runner** (autonomous) | **≥ 95** | block + Slack alert + 停止 | **dirty queue** (`outcome='queued'`) で記録、進行継続 |

night-runner の dirty queue:
- 75 ≤ score < 95 の決定は「bpf なら聞いていたが autonomous なので skip」と記録
- 人間は次セッションで `bpf review queue` で確認、必要なら **retro-approve / retro-reject**（retro-reject はその blueprint を `define` に戻す）

### 9.8 LLM がブレないための anti-drift 装置

1. **連続スコア禁止**: Floor.score は固定値、LLM は数字を作らない
2. **Yes/No 判定のみ**: LLM の自由度は「該当 floor か否か」だけ
3. **構造化 JSON 強制**: free-text の解釈余地を消す
4. **Conservative default**: 判定に迷ったら score=80, `trigger='uncertain'`, ask
5. **Examples per floor**: 各 floor に具体例（positive + negative）を 3 件以上、`rules/review-rubric.md` に列挙
6. **Reject ambiguous trigger**: trigger 文字列は `F1`..`F11` / `default` / `cleanup` / `mechanical` / `uncertain` の closed enum

### 9.9 ルーブリックの保管場所

- 仕様: 本文書 §9（canonical）
- 実装: `rules/review-rubric.md`（各 stack の `.claude.<stack>/rules/` に配置）
- Wave 1 で `rules/review-rubric.md` を作成、coding.md / night-runner SKILL.md から参照

---

## 10. アーキテクチャ図

### 10.1 全体フロー

```
                cores.stage (UX 完成度軸)
                          │
       proto(25%) → mvp(50%) → beta(75%) → prod(100%) → prod_reviewed
                          │                                   │
                          ▼                                   ▼
                  blueprints (frozen=0)              bpf scope 終端
                          │                                   │
              ┌───────────┼───────────┐                       ▼
              │           │           │                post-prod ワークフロー
              ▼           ▼           ▼                (bpf 外、別ツール)
        review_score < 75   75-94   ≥ 95           Playwright E2E
              │           │           │              スクショ + 動画
              ▼           ▼           ▼              マニュアル
       silently proceed   bpf:ask     both:ask       本格 perf/sec 監査
                       night:queue
```

### 10.2 単一 blueprint のクローン進化

```
blueprint "login-page"
├── id=1, stage=proto,  frozen=1, parent=NULL   (UX 25%, 凍結)
├── id=2, stage=mvp,    frozen=1, parent=1      (UX 50%, 凍結)
├── id=3, stage=beta,   frozen=1, parent=2      (UX 75%, 凍結)
└── id=4, stage=prod,   frozen=0, parent=3      ← active (UX 100% 目標)
```

`active_blueprints` view から見えるのは id=4 のみ。

### 10.3 Post-prod 引き継ぎ

```
prod_reviewed (bpf 終端)
   ↓ Slack 通知
別ワークフロー（未設計）
   ├ Playwright E2E コード生成
   ├ 全状態スクショ
   ├ 動画録画（scroll-video 等）
   ├ ユーザーマニュアル生成
   ├ 本格パフォーマンス監査
   └ 本格セキュリティ監査
```

---

## 11. v2 からのマイグレーション

`bpf db migrate-v3` 実行内容（Wave 1a + 1b + 1c）:

- 1a: cores/blueprints に新カラム、`active_blueprints` view、`stage_transitions` + **`review_decisions`** テーブル新設
- 既存 row は `stage='proto'`, `frozen=0` 初期化、`test_l*` step_status は `'test'` に縮約
- 1b: hub.py refactor（view 経由化 + stage コマンド + sync_content 撤去 + knowledge_sets dict 化 + **rubric 統合**）
- 1c: `test_level` カラム drop、`knowledge_sets` テーブル drop

新規プロジェクトは `bpf init` で v3 schema 適用。

---

## 12. サブエージェント提案の処遇（最終）

| # | 内容 | 処遇 |
|---|---|---|
| **#1** | step 簡素化 (test_l1/l2/l3 撤廃) | **v3 採用済**（4 段化） |
| **#3** | sync_content 撤去 | **Wave 1 で実施**（クローンモデルが代替） |
| **#5** | knowledge_sets 撤去 | **Wave 1 で実施**（schema migration 同梱） |
| **#4** | bin/bpf 分離 | **Wave 2 (任意)** |
| **#2** | evaluator-generator 分離 | **Wave 3 (データ駆動)** — `review_decisions` 蓄積で誤判定率を測定し判断 |

#2 の判断データは v3 改訂で追加した `review_decisions` テーブルが直接提供する。これにより Wave 3 のデータ収集が **Wave 1 完了と同時に開始される**（待ち時間なし）。

---

## 13. 未確定の論点

- Slack 通知先: 既存 webhook 流用 (`T3B83CNCF`) vs 専用チャンネル
- `bpf stage review` / `bpf review queue` UI: CLI (TUI) vs Web UI 拡張
- クローン時 content 書き換えオプション (`bpf stage advance --refine-content`)
- post-prod ツールの名前と置き場所
- `bpf init` 時 overview に `## UX Rubric` 雛形を自動挿入するか
- `bpf doctor`（sync_content 撤去の代替・コード/spec ズレ検知）の v3.x 導入可否
- **rubric の Floor 表の調整**: F3a/F4a の境界（contract surface vs 実装詳細）をどう運用上線引きするか。実運用で振れたら調整
- **rubric の閾値 75/95** の調整: dirty queue の規模感を 1 ヶ月運用したら見直し

---

## 14. 参考資料

- 原典: Anthropic "Building Effective AI Agents"
- v2 設計: `BLUEPRINT_FLOW_v2.md`
- Slack webhook: `~/claude/docs/slack-error-notification.md`
- launchd ガイド: `~/claude/docs/launchd-guide.md`
- セッション履歴: `~/.blueprint-flow/.claude/handover.md`

---

## 15. 実装着手手順（次セッション用）

### Wave 1a — Additive schema migration

1. `blueprint/schema.sql` を v3 仕様に更新
2. `bpf db migrate-v3` 実装:
   - cores に stage / stage_dirty 追加
   - blueprints に stage / parent_blueprint_id / frozen 追加
   - `active_blueprints` view 作成
   - `stage_transitions` テーブル作成
   - **`review_decisions` テーブル作成**
3. 既存 row 互換化: `stage='proto'`, `frozen=0`, step_status `test_l*` → `test`

### Wave 1b — hub.py refactor + rubric 統合

4. SELECT 系を `active_blueprints` view 経由化
5. `cmd_complete` 末尾に stage_dirty 検知フック + Slack 通知 + `review_decisions` 記録
6. `hub.py stage <subcommand>` の 4 つ実装
7. **`hub.py review <subcommand>`**（queue / log）実装
8. `sync_content` 撤去
9. `knowledge_sets` クエリ → Python dict (`TYPE_RULES`)
10. **rubric threshold gate**: act execution 前後で coding agent emit JSON を受け取り、`review_decisions` に記録、閾値判定して block / queue / proceed

### Wave 1c — cleanup

11. `blueprints.test_level` drop
12. `knowledge_sets` テーブル drop
13. `bpf:103-110` の `seed_knowledge_sets` 削除

### 並行で

14. **`rules/review-rubric.md` 新規作成**（各 stack に配置、§9 をベースに具体例 3 件ずつ）
15. `rules/stages.md` 新規作成（UX% 共通テンプレ）
16. `bpf init` overview テンプレに `## UX Rubric` 雛形挿入
17. `.claude.*/agents/coding.md` 更新:
    - stage + UX Rubric + review-rubric.md ロード
    - 重要操作前に rubric JSON emit を強制
    - E2E 書かない、UMB 遵守
18. `skills/bpf/SKILL.md` 更新: 閾値 75、stage コマンド一群、`bpf review` コマンド
19. `skills/night-runner/SKILL.md` 更新: 閾値 95、dirty queue ロジック、score ≥ 95 で停止

### Wave 1 完了後

20. blueprint-flow 自体で dogfooding（proto stage で `bpf` を回す）
21. `review_decisions` の蓄積開始 → Wave 3 の誤判定率測定材料に

### Wave 2（任意・Wave 1 安定後）

22. `bin/bpf-new` 分離

### Wave 3（データ駆動）

23. `review_decisions` から `runner='night-runner' AND outcome='queued'` の retro 結果を集計
24. 自己申告 ✓ → 後追い retro-reject 率 > 10% なら evaluator agent 分離を実装

---

## 16. Wave 計画詳細

Wave 編成原則: **ファイル touch 範囲で wave をまとめる**。同じファイルを 2 度開かない。

### Wave 1: v3 stage モデル + #3 + #5 + **rubric** を一括

**touch するファイル**: `schema.sql`, `hub.py`, `bin/bpf`, agents, skills, rules

**含む変更**:
- v3 schema 拡張（stage + clone 履歴 + `review_decisions`）
- hub.py refactor（view 経由化 + stage コマンド + rubric threshold gate）
- sync_content 撤去 (#3)
- knowledge_sets 撤去 (#5)
- review rubric の仕様化と運用化（agents + skills + rules）

**完了基準**:
- `bpf db migrate-v3` 成功
- 既存 blueprint が v3 上で進行可能
- coding agent が rubric JSON を emit、bpf が閾値 75 で block する
- night-runner が閾値 95 で stop、それ未満を dirty queue に貯める
- `bpf review queue` で dirty queue 一覧可能
- sync_content / knowledge_sets が消えても動作

### Wave 2: bin/bpf 分離 (#4)

純 DX、独立。`bin/bpf` を ~400 行に縮退、`bin/bpf-new` を独立化。

### Wave 3: evaluator 分離 (#2)

`review_decisions` データで誤判定率を測定し、>10% なら read-only evaluator subagent を night-runner の quality gate に追加。

---

**v3 ドキュメント終わり。**
