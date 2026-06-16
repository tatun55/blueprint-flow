# Design Axes — 対立軸でデザインを考える

core/design の方針を読み、各軸でどちら寄りかを判断して実装する。
「業種がこうだから」ではなく「この軸の組み合わせだから」で決める。

## 7つの軸

| 軸 | ← 左 | → 右 | CSS的な違い |
|----|-------|-------|------------|
| 密度 | sparse（大きな余白） | dense（情報密集） | gap:2rem+ vs gap:0.5rem, 1カラム vs 多カラム |
| 温度 | cold（slate, navy, 直線） | warm（stone, amber, 曲線） | cool palette vs warm palette, radius:0 vs radius:16px |
| 重力 | light（shadow:none, 薄border） | heavy（multi-shadow, elevation） | border:1px vs box-shadow:4層, flat vs depth |
| 速度 | still（transition:0, 静的） | dynamic（400ms, parallax, scroll） | アニメなし vs scroll-trigger, hover effects |
| 年齢 | classic（serif, editorial） | modern（sans, glassmorphism） | 伝統的フォント vs 幾何学的フォント |
| 音量 | whisper（淡い色差, 微妙） | shout（ビビッド, 高コントラスト） | opacity:0.05差 vs 純色ぶつけ |
| 秩序 | ordered（12列グリッド, 対称） | chaos（非対称, overlap） | grid strict vs 自由配置 |

## 使い方

1. core/design を読む → 方針を軸に翻訳する
2. 翻訳例:
   - 「ミニマル＆プロフェッショナル」→ sparse + cold + light + still + modern + whisper + ordered
   - 「大胆で遊び心」→ dense + warm + heavy + dynamic + modern + shout + chaos
   - 「和の品格」→ sparse + warm + light + still + classic + whisper + ordered
3. 軸の位置に合う CSS 特性を適用する

## スタイリングルール

- **Tailwind CSS ユーティリティのみでスタイリング**
- daisyUI はセマンティックカラークラス（`text-primary`, `bg-base-100` 等）とテーマ機能のみ使用
- daisyUI コンポーネントクラス（`btn`, `card`, `modal` 等）は使用禁止
- 理由: Tailwind 直書きの方がバリエーション・表現力・デザインの自由度が圧倒的に高い

## アンチパターン（軸に関係なく禁止）

- Inter / Arial / Roboto をデフォルトで使う
- 紫グラデーション on 白背景
- 全要素に animate-bounce
- cursor:pointer なしのクリッカブル要素
- 均等配分のパステルパレット
- hover で layout shift する要素
- prefers-reduced-motion を無視
- コントラスト比 4.5:1 未満のテキスト
