# Handover — 2026-05-22 11:30
Scale: large

## Goal
Blueprint-Flow を v2 → V3 に移行する。V3 は UX 完成度ステージモデル (proto/mvp/
beta/prod/prod_reviewed) + クローン進化 + Review Scoring Rubric を持つ。仕様書は
`/Users/a_t/.blueprint-flow/BLUEPRINT_FLOW_v3.md` (唯一の真実)。

## Next
Wave 1b-v に着手:

1. `blueprint/hub.py` の constants 直下に `TYPE_RULES` dict を追加
   - v2 の `seed_knowledge_sets` (`bin/bpf` から削除済み) と同等マッピング
   - 当時の値: `git show caf576a:bin/bpf | sed -n '102,123p'`
2. `cmd_rules` を新規追加 (`hub.py rules <type>` → JSON で type に紐づく rule list)
3. coding agent が `hub.py rules page` で必要 rule を引けるようにする
4. COMMANDS dict に `"rules": cmd_rules` を登録

Wave 1b-v 完了後の候補: `rules/review-rubric.md` 作成 (§9.8 anti-drift)、その後
`rules/stages.md` (§5.2)、coding.md / SKILL.md 更新、#8 ログ隔離。

## Files
### Done (committed on main)
- `e6a37d3` V3 設計書 + 前提資料を main に追加
- `a810bb4` Wave 1a: schema.sql + bpf db migrate-v3
- `0242612` FK バグ fix (self-ref + RENAME)
- `e1af83e` Wave 1b-i/ii: hub.py V3 化 (step_status 4 段 + view 経由化)
- `6bda01e` Wave 1b-iii: stage コマンド群 + クローン進化
- `8b705bd` **Wave 1b-iv: hub.py review/rubric + stage_dirty 検知フック**

### Active (これから触る)
- `blueprint/hub.py` — 冒頭 constants エリアに `TYPE_RULES` 追加、`cmd_rules` を
  cmd_review の直後 (またはレビュー operations 直下) に追加

## State
- ✓ Done:
  - V3 schema (cores stage 列, blueprints stage/parent_blueprint_id/frozen,
    active_blueprints view, stage_transitions, review_decisions)
  - `bpf db migrate-v3` (v2 → V3 破壊的移行、バックアップ自動)
  - Wave 1c 部分前倒し (test_level / 旧 step / parent_id / knowledge_sets drop)
  - hub.py V3 化 (旧 cmd_approve/review 撤去、step_status 4 段で書き換え)
  - SELECT を active_blueprints view 経由化
  - cmd_stage 群 (stage / status / review / advance) + クローン進化アルゴリズム
  - **Wave 1b-iv**: cmd_review (queue/log/record-decision) + stage_dirty 検知 + F2
    自動記録 + Slack 通知 (best-effort、SLACK_DRY_RUN 対応)
- → In progress: Wave 1b-v (TYPE_RULES dict + cmd_rules)
- ⏳ Remaining:
  - `rules/review-rubric.md` 新規作成 (各 floor に positive/negative 例 3 件ずつ)
  - `rules/stages.md` 新規作成 (UX% 共通テンプレ)
  - `coding.md` / `skills/bpf/SKILL.md` / `skills/night-runner/SKILL.md` 更新
  - 新 TODO #8: bpf v3 専用 Claude Code ログ隔離 + 振り返り機構

## Decisions
- **Wave 1c の一部を Wave 1a に前倒し** — SQLite が CHECK/UNIQUE 制約変更で table
  再作成を強制するため。`test_level` / 旧 `step` / `parent_id` / `knowledge_sets` は
  Wave 1a で消失。
- **`parent_blueprint_id` の FK 制約を省略** — SQLite で自己参照 FK +
  ALTER TABLE RENAME すると FK 参照名が古いテーブル名で固定され、新規 INSERT
  で `no such table: blueprints_v3` エラー。仕様書 §4.2 偏差として `INTEGER`
  のみで運用、整合性は hub.py 側で担保。
- **v2 の `parent_id` (test 用親紐づけ) を drop** — 仕様書 §4.2 / §15 未言及。
  test の親紐づけが必要なら将来 dependencies テーブル経由か命名規約で代替。
- **既存 `cmd_approve` / 旧 `cmd_review` を撤去** — todo/review 状態が V3 では
  存在しない。V3 review (queue/log/record-decision) は名前空間が空いていた。
- **dependencies は stage 毎にクローンする** — `_stage_advance` で id_map を作って
  新 stage の id ペアで複製。
- **(Wave 1b-iv) stage_dirty 検知は `_stage_progress` 規約に従い test 除く** —
  既存の done/total 集計 (impl のみ) と一貫させる。test 完了は stage_dirty を
  fire しない。
- **(Wave 1b-iv) Slack webhook は環境変数 `SLACK_WEBHOOK_URL`** — 仕様書 §13
  open question を「env 経由」で resolve。URL をソースに直書きしない。
  `SLACK_DRY_RUN=1` で送信抑止。未設定なら stderr ログのみで silently skip。
- **(Wave 1b-iv) F2 自動記録の runner デフォは bpf** — `hub.py complete <id>
  --runner=night-runner` で night-runner も指定可。stage_dirty 自動発火は最初の
  done 1 回のみで二重発火しない (`if not ov["stage_dirty"]` ガード)。
- **(Wave 1b-iv) <30 のスコアは review_decisions に記録しない** — §9.7 の
  「(≥30 のみ)」記載通り、cleanup/mechanical/極小 default の永続化を回避。
  cmd_review record-decision の outcome は "approved" だが recorded=false で返す。

## Gotchas
- **SQLite で sqlite3 CLI のヒアドキュメントは `.bail on` 必須**。これがないと
  エラー後も後続 SQL を実行し続け、DROP TABLE が走ってデータ消失する事故が起きる。
- **migrate-v3 のバックアップは `blueprint/blueprint.db.v2-backup-YYYYMMDD-HHmmss`**
  に自動作成される。復元コマンドも実行結果に表示される。
- **hub.py のテストは `cd <git管理下>` で行う必要**。`/tmp` だと `cmd_complete` が
  `git add` で失敗する。git init して config user.email/name を設定すれば OK。
- **stage advance 時、test 型 blueprint もクローン対象**。クローン後の test は
  step_status='define' にリセットされるため、新 stage で書き直しが必要。
- **rubric の出力フォーマット (§9.6) は strict JSON enum**。`trigger` は
  `F1`..`F11` / `default` / `cleanup` / `mechanical` / `uncertain` の closed enum。
  hub.py の `TRIGGER_ENUM` で検証している。
- **(Wave 1b-iv) Slack helper は best-effort**。`urllib.request.urlopen` を
  timeout=5 で呼び、失敗時は stderr にログのみ。例外を caller に投げない
  (notification の失敗で git commit や DB 書き込みを失敗させない設計)。
- **(Wave 1b-iv) stage_dirty フックは ns='done' に進めた直後にチェック**。
  途中 step_status (define/impl/test) では fire しない。test 完了でも
  `_stage_progress (test 除く)` が変わらないので fire しない。
- **(Wave 1b-iv) review queue は `outcome='queued' AND runner=?`** で filter。
  default runner は night-runner (`--runner=` 省略時)。
- **TaskList は次セッションに引き継がれない**。タスク状態はこのファイルに書く。

## Verify before trusting
- `v2-wip-archive` ブランチに v2 時代の WIP を退避済み (`bb5ffa4`)。実プロジェクトで
  v2 → V3 移行するときに、有用な改造が残ってないか先に確認すること
  (`git diff main v2-wip-archive -- bin/bpf blueprint/design_shuffle.py`)。
- **TYPE_RULES の中身は v2 の seed_knowledge_sets と同一マッピング** が前提だが、
  Wave 1a で bin/bpf から削除済み。当時の値は git に残ってる:
  `git show caf576a:bin/bpf | sed -n '102,123p'`
- **SLACK_WEBHOOK_URL は ~/claude/docs/slack-error-notification.md に記載の
  既存 webhook を流用予定**。bpf / night-runner skill 側で env を export する
  実装はまだ未着手 (Wave 1b-v 以降の SKILL.md 更新時に対応)。

## Open questions
- `bpf review queue` / `bpf stage review` の UI: CLI (TUI) vs Web UI 拡張 — 仕様書
  §13 未確定論点。当面 CLI で JSON 出力で十分 (Wave 1b-iv で実装済)。
- `rules/review-rubric.md` を chrome-extension stack と tall-daisy stack の両方に
  配置するか、共通化するか。内容は完全同一になりそうなので symlink で集約が clean。
- `cmd_rules` の出力フォーマット (Wave 1b-v): JSON object `{type, rules: [{file, summary}, ...]}` 想定。
  coding agent が `hub.py rules page` の出力をそのまま prompt に詰めるユースケース。

## ⚠ Warning
- **`git log` の `caf576a` 以前は v2 専用**。stage の概念がなく、step (define/seed/
  impl/test_l*/done) と step_status (todo/doing/review/done) の 2 軸構造。V3 着手時
  にここを読んでも v2 知識として扱う。
- **`.claude.tall-daisy/CLAUDE.md` は v3 を反映していない可能性**。stage モデルに
  合わせて補強が必要かは未検討。
- **`v2-wip-archive` ブランチには `BLUEPRINT_FLOW_v3.md` を含む V3 前提資料も
  入っている**。これは main にも分離コミット済み (`e6a37d3`) なので、archive 側の
  V3 ファイルは無視してよい。

## User preferences (guiding principles)
- **「コーディング原則」厳守** (`~/.claude/CLAUDE.md` 参照): Surgical Changes /
  Verified Done / Stop and Report。各サブステップでテスト + 報告。一気に進めない。
- **AskUserQuestion で確認**: 仕様書偏差・選択肢が生じる判断点は推奨案 + 代案で
  提示。デフォルトで仕様書通り進めず、技術的制約があれば偏差を明示。
- **Wave 単位でコミット分割**: バグ修正と機能追加を混ぜない。仕様書偏差はコミット
  メッセージで明示。
- **日本語で対話**。コミットメッセージも基本日本語。コード内コメントも日本語可
  (運用上の理由を残す)。

## Stop energy
- ❌ **`step_status` に v2 値 (todo/doing/review) を残す案** — V3 CHECK 制約と矛盾。
- ❌ **stage を blueprint 単位で持つ案** — active_blueprints view と矛盾。
  stage は cores.overview 1 個で持つ。
- ❌ **knowledge_sets テーブルを残す案** — 仕様書 §4.6 で明示削除、Python dict 化が決定済み。
- ❌ **Slack webhook URL をソースに直書き** — 既存 webhook を env 経由で渡す
  パターンに決定 (Wave 1b-iv)。

## Glossary
- **stage** ← (旧: なし、概念導入は v3 から) — UX 完成度 % 軸。proto/mvp/beta/prod/prod_reviewed
- **step_status** (V3) ← (v2: step + step_status の 2 軸) — define→impl→test→done の 4 段単一軸
- **active_blueprints** ← (新規 view) — cores.stage と一致する frozen=0 の blueprint
- **frozen** ← (新規) — 過去 stage の blueprint は frozen=1 で履歴保存
- **クローン進化** ← (新規) — stage advance 時に旧 stage を frozen 化、新 stage 用に
  全 blueprint を複製
- **review_decisions** ← (新規) — rubric 判定の監査ログ、Wave 3 evaluator 分離の
  データソース兼用
- **rubric / Review Scoring Rubric** ← (新規) — 失敗モード MECE 軸 (L/K/D/G) +
  Floor 表 (F1..F11 fixed score) で LLM がブレずに判定する 0-100 スコア体系
- **dirty queue** ← (新規、Wave 1b-iv で実装) — night-runner で 75≤score<95 の
  判定を `outcome='queued'` で記録。`hub.py review queue` で人間が retro 確認

## Dependencies (decision-to-decision)
- `parent_blueprint_id` FK 省略 → アプリ側 (hub.py の `_stage_advance`) で
  parent 整合性を担保する必要。
- Wave 1c 前倒し → Wave 1b-v の TYPE_RULES dict 追加が「knowledge_sets 撤去後の
  代替」として必須に。
- Slack webhook env 化 → bpf / night-runner skill の起動時に `SLACK_WEBHOOK_URL`
  を export する必要 (SKILL.md 更新時)。
- Wave 1b-iv stage_dirty 検知 → 「stage advance ready」検知が hub.py 内で完結
  したので、bpf skill 側の polling は不要。

## Proof status
- Wave 1a / 1b-i / 1b-ii / 1b-iii / **1b-iv** の動作 — **verified**:
  `/tmp/bpf-migrate-test` および `/tmp/bpf-wave1b-iv-test` で
  schema migration → hub.py 全コマンド → stage advance 全段 + クローン進化 →
  cmd_review (各 floor × 各 runner) → stage_dirty 検知 → F2 自動記録 →
  Slack dry-run まで全 17 ケース確認。
- 仕様書偏差 2 件 (Wave 1c 前倒し、parent FK 省略) — **user-asserted**: ユーザーは
  AskUserQuestion で承諾。後で振り返りで再評価予定。
- `rules/review-rubric.md` の必要性 — **literature**: 仕様書 §9 + handover に
  「anti-drift には positive + negative 例 3 件ずつが核」と記載、実装はまだ未着手。
- `bpf v3 専用ログ隔離` (#8) — **assumed**: ユーザーから「hooks などで？」と
  曖昧な指示、設計はまだ。
