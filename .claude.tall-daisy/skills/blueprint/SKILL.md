# Blueprint Skill

仕様策定・プロジェクト状況把握・開発フロー提案

## サブコマンド

### `/blueprint pull`

blueprint-flowサブモジュールを最新版に更新する。

```bash
cd .blueprint-flow && git pull origin main && cd ..
./.blueprint-flow/scripts/update.sh
```

実行後、変更内容を報告。

---

## 引数なしの場合

1. プロジェクト状況を確認
```bash
./scripts/blueprint-db-cli.sh overview
./scripts/blueprint-db-cli.sh progress
```

2. 状況を分析して推奨アクションをAskUserQuestionで提示
   - draft が多い → 「仕様策定を続けますか？」
   - pending_review が多い → 「レビュー待ちが N件あります」
   - approved が多い → 「/db または /coding で実装を開始できます」
   - in_progress が多い → 「実装中のspecがN件あります」

## 引数ありの場合

`$ARGUMENTS` を解釈して仕様を策定・更新

1. 既存specの更新 or 新規作成を判定
2. 適切なcategory/typeを判定
3. 情報が足りない場合はAskUserQuestionで取得
4. specを作成/更新

### Blueprint仕様の品質基準

1. **コーディング可能** - 実装者が迷わず着手できる
2. **具体的** - 曖昧さがない
3. **詳細** - 必要な情報が揃っている
4. **意図が明確** - なぜこの仕様かが分かる
5. **無駄がない** - 冗長な記述を避ける
6. **正確** - 誤解の余地がない

## CLIコマンド

```bash
./scripts/blueprint-db-cli.sh overview         # 全spec一覧
./scripts/blueprint-db-cli.sh progress         # status別の進捗
./scripts/blueprint-db-cli.sh available        # 実装可能なspec
./scripts/blueprint-db-cli.sh pending-review   # レビュー待ち
./scripts/blueprint-db-cli.sh needs-attention  # 要対応
./scripts/blueprint-db-cli.sh add <cat> <type> <slug> <name> '<json>'
./scripts/blueprint-db-cli.sh update <id> '<json>'
./scripts/blueprint-db-cli.sh status <id> <status>
```

## Status Flow

```
draft → pending_review → approved → in_progress → impl_review → testing → done
              ↑                           ↓
              └────── needs_revision ←────┘
```
