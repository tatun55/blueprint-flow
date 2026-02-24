---
name: demo-lp
description: デモLP並列生成。指定数のSonnetエージェントを同時起動し、各自がdesign_shuffleで素材を取得→コンセプトに合った高品質LPを自律生成する。
allowed-tools: Bash, Read, Grep, Glob, Task, AskUserQuestion, TodoWrite, TaskOutput
user-invocable: true
---

# Demo LP Generator

デモLP並列生成スキル。各Sonnetエージェントが自律的にデザイン素材を取得し、
プロジェクトコンセプトに合った製品レベルのLPを生成する。

## 起動方法

```
/demo-lp                              → 3つ生成
/demo-lp 5                            → 5つ生成
/demo-lp 3 warm organic               → 基本方向性を指定して3つ生成
```

## 実行フロー

### Step 1: 引数パース

args から以下を抽出:
- `count`: 最初の数字引数（デフォルト 3）
- `base_design`: 数字以外の引数すべてを結合（デフォルト なし）

### Step 2: コンセプト取得

```bash
python3 .blueprint-flow/blueprint/hub.py read-core concept
```

出力 JSON から `content` フィールドを取得。

### Step 2.5: Frontend Design スキル読み込み

サブエージェントは Skill ツールを使えないため、オーケストレーター側でスキル定義を読み込みプロンプトに埋め込む。

1. Glob で `~/.claude/plugins/cache/claude-code-plugins/frontend-design/**/SKILL.md` を検索
2. 見つかったファイルを Read で取得
3. YAML frontmatter（先頭の `---` 〜 `---` ブロック）を除去し、本文を `{frontend_design_skill}` に格納

見つからない場合はエラーを出さず、`{frontend_design_skill}` を空文字にしてフォールバック（エージェントプロンプト内の品質基準セクションが補完する）。

### Step 3: エージェント並列起動

**ファイル名の決定（衝突回避）:**

`blueprint/demos/` 内の既存 `design-*.html` を Glob で取得し、最大の番号 + 1 から連番を振る。
ファイル名は `design-{NNN}.html`（零埋め3桁: 001, 002, ...）。

**エージェント起動:**

count 個の Task を **1つのメッセージで同時に** 起動する。

各エージェントの設定:
- `subagent_type`: "general-purpose"
- `model`: "sonnet"
- `run_in_background`: true

各エージェントには異なる seed を割り当てる（index × 1000 + タイムスタンプ下4桁など）。
ファイル名は `design-{NNN}.html`（上記で確保した連番）。

### Step 4: 完了待ち + 報告

全エージェントの TaskOutput を待ち、完了後にファイルパス一覧を報告。

---

## エージェントプロンプトテンプレート

以下のテンプレートで各エージェントを起動する。
`{変数}` は Step 1〜2.5 の値で置換すること。

<agent-prompt>
あなたは製品レベルのLP専門デザイナーエージェントです。
ProtFitプロジェクトの高品質なデモLPを1つ作成してください。

## 出力先

`blueprint/demos/design-{NNN}.html`（単体で開けるスタンドアロン HTML）

## プロジェクトコンセプト

{concept_content}

## 基本デザイン方向性

{base_design}

上記が「なし」の場合は自由にデザイン方向性を決定してよい。
指定がある場合はそれを最優先の制約として守りつつ、独自の解釈でバリエーションを出すこと。

## デザイン素材の取得

まず以下のコマンドを実行してデザインのヒントを取得せよ:

```bash
python3 .blueprint-flow/blueprint/design_shuffle.py --seed {seed} --concept --hints
```

出力されたヒント（1〜3つのスタイル候補）は**アイデアのきっかけ**として使う。
仕様書ではなくインスピレーション素材である:
- ヒントの中からプロダクトコンセプトに合う要素だけを取り入れる
- 1つのヒントだけ採用してもよいし、複数を掛け合わせてもよい
- ヒントに縛られず、コンセプトに最適なデザインを自律的に創出せよ
- 基本デザイン方向性が指定されている場合はそれを最優先する

## Frontend Design スキル（デザイン品質ガイドライン）

以下は frontend-design スキルから自動埋め込みされたデザイン品質基準である。
**このガイドラインに従ってデザインせよ。**

{frontend_design_skill}

## LP固有の品質基準

### デザイン思想

コードを書く前に、明確な美的方向性にコミットせよ:
- **目的**: このLPは何を解決するか？ スタートアップ創業者に需要検証の一気通貫ツールを訴求する
- **差別化**: このLPで何が「忘れられない」か？ 1つの要素に集中せよ

## 必須セクション

1. **Nav** — 固定ナビゲーション（ロゴ + アンカーリンク + CTAボタン）
2. **Hero** — フルビューポート。キャッチコピーを中心に、印象的なビジュアル
3. **Features** — ProtFitの3つの特徴（ＡＩ駆動LP生成 / 広告自動運用 / ABテスト自動改善）
4. **How It Works** — 3ステップの利用フロー
5. **CTA** — メールアドレス入力 or ボタン。行動を促すセクション
6. **Footer** — ロゴ、リンク、コピーライト

## 技術ルール

- `<script src="https://cdn.tailwindcss.com"></script>` で Tailwind CSS 読み込み
- `tailwind.config` をインラインで定義（カスタムカラー・フォント・角丸等）
- Google Fonts CDN でフォント読み込み（`<link rel="preconnect">` + `<link href="...">` ）
- daisyUI コンポーネントクラス使用禁止（btn, card, modal, badge, navbar 等）
- `<style>` ブロックでカスタム CSS（shadow utilities, keyframe animations, scroll-reveal 等）
- IntersectionObserver でスクロール表示アニメーション実装
- mobile-first レスポンシブ（sm: → md: → lg:）
- コンセプトに沿った日本語コピーライティング
- 「ＡＩ」は全角表記

## 絶対禁止

- Inter, Roboto, Arial 等の汎用フォント
- 紫グラデーション on 白背景のような陳腐なＡＩ生成風デザイン
- cookie-cutter な汎用レイアウト
- 「別のＡＩに同じ指示を出して同じ結果が出たら、それは失敗」— 唯一無二の個性を出すこと

## 最終チェック

HTMLを書き終えたら、以下を確認:
1. 全セクション（Nav/Hero/Features/How It Works/CTA/Footer）が存在するか
2. レスポンシブ（モバイル表示で崩れないか）
3. フォントが正しく読み込まれるか（Google Fonts CDN リンク）
4. アニメーションが動作するか（IntersectionObserver）
5. 日本語コピーがコンセプトに沿っているか
</agent-prompt>
