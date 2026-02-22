#!/usr/bin/env python3
"""Design Axes Shuffler — industry-bias-free design combination generator.

Generates coherent design combinations along 7 aesthetic axes.
Each run produces different results (seeded by timestamp).

Usage:
  python3 design_shuffle.py                    # random axis profile, 3 combos
  python3 design_shuffle.py --seed 42          # reproducible output
  python3 design_shuffle.py --axes sparse cold light still classic whisper ordered
"""

import json
import random
import sys

# ── 7 Aesthetic Axes ──────────────────────────────────────────
# Each axis: -1 (left) ← 0 (neutral) → +1 (right)
AXES = {
    "density":  ("sparse",  "dense"),    # 余白 ←→ 情報密集
    "temp":     ("cold",    "warm"),     # 冷たい ←→ 暖かい
    "gravity":  ("light",   "heavy"),    # 軽い ←→ 重い
    "speed":    ("still",   "dynamic"),  # 静的 ←→ 動的
    "age":      ("classic", "modern"),   # 古典 ←→ 現代
    "volume":   ("whisper", "shout"),    # 囁き ←→ 叫び
    "order":    ("ordered", "chaos"),    # 秩序 ←→ 混沌
}

# ── Styles (distilled from 67 styles, industry labels removed) ──
STYLES = [
    {"name": "Minimalism",       "css": "radius:0, shadow:none, grid-based",           "effect": "subtle hover 200ms",              "axes": {"density":-1,"temp":-1,"gravity":-1,"speed":-1,"age":0, "volume":-1,"order":1}},
    {"name": "Neumorphism",      "css": "radius:14px, multi-layer soft-shadow",        "effect": "soft press 150ms",                "axes": {"density":-1,"temp":0.5,"gravity":-0.5,"speed":-1,"age":1, "volume":-1,"order":1}},
    {"name": "Glassmorphism",    "css": "blur:15px, rgba overlay, 1px border",         "effect": "backdrop blur, light reflection",  "axes": {"density":-0.5,"temp":-0.5,"gravity":-0.5,"speed":0,"age":1, "volume":-0.5,"order":1}},
    {"name": "Brutalism",        "css": "radius:0, border:3px solid, bold 700+",       "effect": "instant transitions, no easing",  "axes": {"density":0.5,"temp":-1,"gravity":1,"speed":-1,"age":-0.5, "volume":1,"order":-1}},
    {"name": "Neubrutalism",     "css": "shadow:4px 4px 0 #000, border:3px",           "effect": "sharp corners, no gradients",     "axes": {"density":0,"temp":-0.5,"gravity":0.5,"speed":-0.5,"age":1, "volume":0.8,"order":-0.5}},
    {"name": "Flat Design",      "css": "no shadows, solid colors, clean borders",     "effect": "color/opacity hover, fast load",  "axes": {"density":-0.5,"temp":0,"gravity":-1,"speed":-1,"age":0.5, "volume":-0.5,"order":1}},
    {"name": "Dark OLED",        "css": "#000 bg, minimal glow, high contrast",        "effect": "dark-to-light transitions",       "axes": {"density":-0.5,"temp":-1,"gravity":0.5,"speed":-0.5,"age":1, "volume":-0.5,"order":1}},
    {"name": "Claymorphism",     "css": "inner+outer shadow, pastel, radius:16px",     "effect": "soft press 200ms, fluffy feel",   "axes": {"density":-0.5,"temp":1,"gravity":-0.5,"speed":-0.5,"age":1, "volume":-0.5,"order":0.5}},
    {"name": "Aurora UI",        "css": "gradient mesh, complementary colors",          "effect": "flowing 8-12s animations",        "axes": {"density":-0.5,"temp":0.5,"gravity":-0.5,"speed":0.5,"age":1, "volume":0,"order":-0.5}},
    {"name": "Retro-Futurism",   "css": "neon glow, CRT scanlines, deep black bg",     "effect": "glitch effect, neon pulse",       "axes": {"density":0.5,"temp":-0.5,"gravity":0.5,"speed":0.5,"age":-1, "volume":0.8,"order":-0.5}},
    {"name": "Vibrant Block",    "css": "neon colors, 48px+ gaps, large sections",     "effect": "bold hover, scroll reveal",       "axes": {"density":0.5,"temp":0.5,"gravity":0.5,"speed":0.5,"age":1, "volume":1,"order":-0.5}},
    {"name": "Bento Grid",       "css": "varied grid spans, radius:16px, soft shadow", "effect": "hover scale 1.02, content reveal","axes": {"density":0,"temp":-0.5,"gravity":-0.5,"speed":-0.5,"age":1, "volume":-0.5,"order":1}},
    {"name": "Editorial Grid",   "css": "12-col grid, high contrast B/W, accent",      "effect": "scroll reveal, parallax images",  "axes": {"density":0,"temp":-0.5,"gravity":0,"speed":0,"age":-0.5, "volume":0,"order":1}},
    {"name": "Swiss Modernism",  "css": "mathematical ratios, 12-col, single accent",  "effect": "grid-based rhythm, precision",    "axes": {"density":0,"temp":-1,"gravity":-0.5,"speed":-1,"age":-0.5, "volume":-0.5,"order":1}},
    {"name": "Organic Biophilic","css": "radius:16-24px, organic curves, nature tex",   "effect": "natural shadow, soft parallax",   "axes": {"density":-0.5,"temp":1,"gravity":-0.5,"speed":-0.5,"age":-0.5, "volume":-0.5,"order":-0.5}},
    {"name": "E-Ink Paper",      "css": "off-white #FDFBF7, ink #1A1A1A, grain tex",   "effect": "no motion blur, sharp transitions","axes": {"density":-1,"temp":0.5,"gravity":-1,"speed":-1,"age":-1, "volume":-1,"order":1}},
    {"name": "Cyberpunk",        "css": "neon on black, matrix green, magenta",         "effect": "glitch, scanlines, neon glow",    "axes": {"density":0.5,"temp":-1,"gravity":0.5,"speed":1,"age":0.5, "volume":1,"order":-1}},
    {"name": "Liquid Glass",     "css": "iridescent, translucent, morphing shapes",     "effect": "fluid 400-600ms, dynamic blur",   "axes": {"density":-0.5,"temp":0,"gravity":-0.5,"speed":1,"age":1, "volume":0,"order":-0.5}},
    {"name": "Nature Distilled", "css": "terracotta, sand, clay tones, texture",        "effect": "natural easing, grain overlay",   "axes": {"density":-0.5,"temp":1,"gravity":0,"speed":-0.5,"age":-0.5, "volume":-0.5,"order":0.5}},
    {"name": "Exaggerated Min",  "css": "B/W + 1 accent, clamp(3rem,10vw,12rem)",       "effect": "massive type, extreme whitespace","axes": {"density":-1,"temp":-0.5,"gravity":0,"speed":-1,"age":1, "volume":0.5,"order":1}},
    {"name": "Dimensional Layer","css": "4-level elevation, translateZ, stacking",      "effect": "z-depth parallax, shadow layers", "axes": {"density":0,"temp":-0.5,"gravity":0.5,"speed":0,"age":1, "volume":0,"order":1}},
    {"name": "Memphis Design",   "css": "hot pink, yellow, teal, geometric shapes",     "effect": "rotate, clip-path, patterns",     "axes": {"density":0.5,"temp":1,"gravity":0,"speed":0.5,"age":-0.5, "volume":1,"order":-1}},
    {"name": "Anti-Polish Raw",  "css": "paper white, pencil grey, hand-drawn feel",    "effect": "no smooth transitions, jitter",   "axes": {"density":-0.5,"temp":0.5,"gravity":-0.5,"speed":-0.5,"age":0, "volume":0,"order":-0.5}},
    {"name": "Vaporwave",        "css": "pink, cyan, mint, purple, gradient",           "effect": "hue-rotate, glitch, retro glow",  "axes": {"density":0,"temp":0.5,"gravity":-0.5,"speed":0.5,"age":-1, "volume":0.5,"order":-0.5}},
]

# ── Font Pairings (distilled, industry labels removed) ──
FONTS = [
    {"heading": "Playfair Display", "body": "DM Sans",               "mood": "elegant, refined, editorial",     "axes": {"temp":0.5,"age":-1,"volume":-0.5,"order":1}},
    {"heading": "Space Grotesk",    "body": "DM Sans",               "mood": "tech, innovative, futuristic",    "axes": {"temp":-0.5,"age":1,"volume":0,"order":1}},
    {"heading": "Cormorant Garamond","body": "Libre Baskerville",    "mood": "literary, traditional, bookish",  "axes": {"temp":0.5,"age":-1,"volume":-0.5,"order":1}},
    {"heading": "Fredoka",          "body": "Nunito",                 "mood": "playful, friendly, rounded",      "axes": {"temp":1,"age":0.5,"volume":0.5,"order":-0.5}},
    {"heading": "Bebas Neue",       "body": "Source Sans 3",          "mood": "bold, impactful, dramatic",       "axes": {"temp":0,"age":0,"volume":1,"order":0.5}},
    {"heading": "Lora",             "body": "Raleway",                "mood": "calm, natural, organic",          "axes": {"temp":0.5,"age":-0.5,"volume":-1,"order":0.5}},
    {"heading": "JetBrains Mono",   "body": "IBM Plex Sans",         "mood": "precise, technical, functional",  "axes": {"temp":-1,"age":0.5,"volume":-0.5,"order":1}},
    {"heading": "Outfit",           "body": "Work Sans",              "mood": "geometric, balanced, clean",      "axes": {"temp":0,"age":0.5,"volume":0,"order":1}},
    {"heading": "Syne",             "body": "Manrope",                "mood": "avant-garde, artistic, bold",     "axes": {"temp":0,"age":1,"volume":0.5,"order":-0.5}},
    {"heading": "Plus Jakarta Sans","body": "Plus Jakarta Sans",      "mood": "friendly, approachable, modern",  "axes": {"temp":0.5,"age":1,"volume":0,"order":1}},
    {"heading": "Abril Fatface",    "body": "Merriweather",           "mood": "retro, nostalgic, decorative",    "axes": {"temp":0.5,"age":-1,"volume":0.5,"order":0.5}},
    {"heading": "Noto Serif JP",    "body": "Noto Sans JP",           "mood": "和の品格, 伝統と現代の融合",        "axes": {"temp":0.5,"age":-0.5,"volume":-0.5,"order":1}},
    {"heading": "Clash Display",    "body": "Satoshi",                "mood": "confident, dynamic, startup",     "axes": {"temp":0,"age":1,"volume":0.8,"order":0.5}},
    {"heading": "Bodoni Moda",      "body": "Jost",                   "mood": "luxury, minimalist, high-end",    "axes": {"temp":0,"age":-0.5,"volume":-0.5,"order":1}},
    {"heading": "Space Mono",       "body": "Space Mono",             "mood": "raw, monospace, stark",           "axes": {"temp":-1,"age":0,"volume":0,"order":0.5}},
    {"heading": "Lexend Mega",      "body": "Public Sans",            "mood": "loud, geometric, strong",         "axes": {"temp":0,"age":1,"volume":1,"order":0}},
    {"heading": "Poiret One",       "body": "Didact Gothic",          "mood": "art deco, vintage, decorative",   "axes": {"temp":0.5,"age":-1,"volume":0,"order":1}},
    {"heading": "Anton",            "body": "Epilogue",               "mood": "brutal, shouty, internet",        "axes": {"temp":0,"age":1,"volume":1,"order":-0.5}},
    {"heading": "Caveat",           "body": "Quicksand",              "mood": "handwritten, personal, casual",   "axes": {"temp":1,"age":0,"volume":-0.5,"order":-1}},
    {"heading": "Atkinson Hyper",   "body": "Atkinson Hyperlegible",  "mood": "accessible, inclusive, readable",  "axes": {"temp":0,"age":0.5,"volume":0,"order":1}},
]

# ── Color Palettes (pure aesthetic, no industry labels) ──
PALETTES = [
    {"name": "Ice & Signal",     "primary":"#0F172A","accent":"#F97316","bg":"#F8FAFC","text":"#1E293B", "axes": {"temp":-1,"volume":0.5}},
    {"name": "Midnight Emerald", "primary":"#0F172A","accent":"#10B981","bg":"#020617","text":"#F8FAFC", "axes": {"temp":-0.5,"volume":0}},
    {"name": "Ink & Gold",       "primary":"#1C1917","accent":"#CA8A04","bg":"#FAFAF9","text":"#0C0A09", "axes": {"temp":0.5,"volume":0.5}},
    {"name": "Indigo Dream",     "primary":"#6366F1","accent":"#10B981","bg":"#F5F3FF","text":"#1E1B4B", "axes": {"temp":-0.5,"volume":0}},
    {"name": "Forest Depth",     "primary":"#059669","accent":"#F97316","bg":"#ECFDF5","text":"#064E3B", "axes": {"temp":0.5,"volume":0}},
    {"name": "Pure Mono",        "primary":"#000000","accent":"#0080FF","bg":"#FFFFFF","text":"#000000", "axes": {"temp":-1,"volume":-0.5}},
    {"name": "Warm Stone",       "primary":"#78716C","accent":"#EA580C","bg":"#F5F5F4","text":"#1C1917", "axes": {"temp":1,"volume":-0.5}},
    {"name": "Neon Void",        "primary":"#000000","accent":"#00FF00","bg":"#0A0A0A","text":"#00FF00", "axes": {"temp":-1,"volume":1}},
    {"name": "Blush & Slate",    "primary":"#64748B","accent":"#F472B6","bg":"#F8FAFC","text":"#334155", "axes": {"temp":0.5,"volume":-0.5}},
    {"name": "Terracotta Sun",   "primary":"#C67B5C","accent":"#D97706","bg":"#FFFBEB","text":"#451A03", "axes": {"temp":1,"volume":0}},
    {"name": "Arctic Steel",     "primary":"#334155","accent":"#22D3EE","bg":"#F1F5F9","text":"#0F172A", "axes": {"temp":-1,"volume":0}},
    {"name": "Violent Contrast", "primary":"#FF0000","accent":"#FFFF00","bg":"#000000","text":"#FFFFFF", "axes": {"temp":0,"volume":1}},
    {"name": "Sage Whisper",     "primary":"#6B7280","accent":"#84CC16","bg":"#FAFAF9","text":"#1F2937", "axes": {"temp":0.5,"volume":-1}},
    {"name": "Deep Amethyst",    "primary":"#581C87","accent":"#F59E0B","bg":"#1E1B4B","text":"#E9D5FF", "axes": {"temp":0,"volume":0.5}},
    {"name": "Paper & Ink",      "primary":"#1A1A1A","accent":"#B91C1C","bg":"#FDFBF7","text":"#1A1A1A", "axes": {"temp":0.5,"volume":-0.5}},
]

# ── Core Logic ──

def axis_distance(profile, element_axes):
    """Compute similarity between an axis profile and an element's axes."""
    score = 0.0
    matched = 0
    for axis, val in element_axes.items():
        if axis in profile:
            diff = abs(profile[axis] - val)
            score += 1.0 - diff  # closer = higher score
            matched += 1
    return score / max(matched, 1)


def random_profile():
    """Generate a random axis profile with character (not all neutral)."""
    profile = {}
    for axis in AXES:
        r = random.random()
        if r < 0.3:
            profile[axis] = -1  # left extreme
        elif r < 0.5:
            profile[axis] = -0.5
        elif r < 0.7:
            profile[axis] = 0.5
        else:
            profile[axis] = 1   # right extreme
    return profile


def parse_axis_words(words):
    """Parse axis words like 'sparse cold light' into a profile."""
    word_map = {}
    for axis, (left, right) in AXES.items():
        word_map[left] = (axis, -1)
        word_map[right] = (axis, 1)
    profile = {}
    for w in words:
        w = w.lower().strip()
        if w in word_map:
            axis, val = word_map[w]
            profile[axis] = val
    # Fill missing with random
    for axis in AXES:
        if axis not in profile:
            profile[axis] = random.choice([-0.5, 0.5])
    return profile


def select_top(items, profile, n=3):
    """Select top N items by axis similarity, with randomized tiebreaking."""
    scored = []
    for item in items:
        axes = item.get("axes", {})
        score = axis_distance(profile, axes) + random.uniform(0, 0.15)
        scored.append((score, item))
    scored.sort(key=lambda x: -x[0])
    return [item for _, item in scored[:n]]


def generate(profile, count=3):
    """Generate design combinations for an axis profile."""
    styles = select_top(STYLES, profile, count)
    fonts = select_top(FONTS, profile, count)
    palettes = select_top(PALETTES, profile, count)
    combos = []
    for i in range(count):
        combos.append({
            "style": styles[i],
            "font": fonts[i],
            "palette": palettes[i],
        })
    return combos


def format_profile(profile):
    """Format axis profile as human-readable string."""
    parts = []
    for axis, (left, right) in AXES.items():
        val = profile.get(axis, 0)
        if val <= -0.5:
            parts.append(left)
        elif val >= 0.5:
            parts.append(right)
    return " + ".join(parts) if parts else "neutral"


def format_output(profile, combos):
    """Format combinations as compact readable output."""
    lines = [f"Axis Profile: {format_profile(profile)}", ""]
    for i, c in enumerate(combos):
        s, f, p = c["style"], c["font"], c["palette"]
        lines.append(f"── Combo {chr(65+i)} ──────────────────────────")
        lines.append(f"  Style:  {s['name']}")
        lines.append(f"  CSS:    {s['css']}")
        lines.append(f"  Effect: {s['effect']}")
        lines.append(f"  Font:   {f['heading']} → {f['body']} ({f['mood']})")
        lines.append(f"  Color:  {p['name']} — primary:{p['primary']} accent:{p['accent']} bg:{p['bg']}")
        lines.append("")
    return "\n".join(lines)


def format_design_spec(profile, combo):
    """Format a single combo as a full Markdown global design system for set-design stdin.

    This spec is read by coding agents on every page/partial/layout implementation.
    It must contain enough detail for an agent to produce consistent, high-quality UI
    across all pages without further design guidance.
    """
    s, f, p = combo["style"], combo["font"], combo["palette"]
    return f"""## 軸プロファイル
{format_profile(profile)}

## ベーススタイル
- 名前: {s['name']}
- CSS 特性: {s['css']}
- エフェクト: {s['effect']}

## タイポグラフィ
- 見出しフォント: {f['heading']}
- 本文フォント: {f['body']}
- フォントトーン: {f['mood']}
- サイズスケール（Tailwind）:
  - h1: text-4xl md:text-5xl font-bold
  - h2: text-2xl md:text-3xl font-semibold
  - h3: text-xl md:text-2xl font-semibold
  - body: text-base leading-relaxed
  - small: text-sm
  - caption: text-xs

## カラーパレット
- 名前: {p['name']}
- primary: {p['primary']}
- accent: {p['accent']}
- background: {p['bg']}
- text: {p.get('text', '#1A1A1A')}
- 使い方:
  - primary → ナビ、重要ボタン、見出し背景
  - accent → CTA、ホバー、アクティブ状態、リンク
  - background → ページ全体の bg
  - text → 本文テキスト
  - primary/accent の opacity 変化で secondary/subtle を作る

## コンポーネントスタイルガイド

### ボタン
- プライマリ: bg-[primary] text-white hover:opacity-90 transition-all
- セカンダリ: border border-[primary] text-[primary] hover:bg-[primary] hover:text-white
- アクセント: bg-[accent] text-white hover:opacity-90
- サイズ: px-6 py-3 text-sm font-medium（標準）、px-4 py-2 text-xs（小）
- 角丸: コンセプトに応じて Hub が決定

### カード
- bg-white（またはbg-[background]の1段明るい/暗い）
- パディング: p-6
- 影・ボーダー: コンセプト「{s['css']}」に準拠
- ホバー: {s['effect']}

### フォーム
- input: border border-gray-300 focus:border-[accent] focus:ring-2 focus:ring-[accent]/20
- label: text-sm font-medium text-[text]
- error: text-red-500 text-xs mt-1

### ナビゲーション
- bg-[primary] text-white（ダークナビ）または bg-[background] border-b（ライトナビ）
- アクティブリンク: border-b-2 border-[accent] または bg-[accent]/10
- 高さ: h-16

### テーブル
- ヘッダ: bg-gray-50 text-xs uppercase tracking-wider
- 行: hover:bg-gray-50 transition-colors
- ボーダー: divide-y divide-gray-200

### モーダル
- backdrop: bg-black/50
- パネル: bg-white rounded-lg shadow-xl max-w-lg mx-auto
- アニメーション: {s['effect']}

## スタイリングルール
- Tailwind CSS ユーティリティのみ使用
- daisyUI はセマンティックカラークラスとテーマ機能のみ（コンポーネントクラス禁止）
- custom CSS 禁止
- レスポンシブ: mobile-first（sm: → md: → lg:）
- prefers-reduced-motion 対応必須

## レイアウト方針
（コンセプトに応じて Hub が決定）

## 特記事項
（なし）"""


def main():
    args = sys.argv[1:]
    seed = None

    if "--seed" in args:
        idx = args.index("--seed")
        seed = int(args[idx + 1])
        args = args[:idx] + args[idx+2:]

    if "--json" in args:
        json_mode = True
        args.remove("--json")
    else:
        json_mode = False

    if "--markdown" in args:
        md_mode = True
        md_idx = args.index("--markdown")
        md_pick = int(args[md_idx + 1]) if md_idx + 1 < len(args) and args[md_idx + 1].isdigit() else 0
        args = args[:md_idx] + args[md_idx+2:] if md_idx + 1 < len(args) and args[md_idx + 1].isdigit() else args[:md_idx] + args[md_idx+1:]
    else:
        md_mode = False
        md_pick = 0

    random.seed(seed)

    if "--axes" in args:
        idx = args.index("--axes")
        axis_words = args[idx+1:]
        profile = parse_axis_words(axis_words)
    else:
        profile = random_profile()

    combos = generate(profile, 3)

    if md_mode:
        # Output Markdown design spec for a single combo (0=A, 1=B, 2=C)
        print(format_design_spec(profile, combos[min(md_pick, len(combos)-1)]))
    elif json_mode:
        out = {"profile": profile, "profile_label": format_profile(profile), "combos": []}
        for c in combos:
            out["combos"].append({
                "style": c["style"]["name"],
                "css": c["style"]["css"],
                "effect": c["style"]["effect"],
                "heading_font": c["font"]["heading"],
                "body_font": c["font"]["body"],
                "font_mood": c["font"]["mood"],
                "palette": c["palette"]["name"],
                "primary": c["palette"]["primary"],
                "accent": c["palette"]["accent"],
                "bg": c["palette"]["bg"],
            })
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(format_output(profile, combos))


if __name__ == "__main__":
    main()
