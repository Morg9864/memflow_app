# Design System — MemFlow

## Overview

MemFlow is a warm, editorial study companion for students. The visual personality centers on a soft cream canvas (#FAF6EF), deep warm-brown typography (#2B241D), and orange (#D97B3F) as the single high-energy accent. The layout is intentionally spacious and focused — cards, metrics, and session UI breathe freely. The tone is inviting and confident without being loud: warmth comes from the palette, not effects. Motion is premium — smooth reveals, slow pushes, never aggressive. The brand feels like a well-crafted notebook, not a tech dashboard.

## Colors

- **Primary Surface**: `#FAF6EF` — warm cream, primary background for all light scenes
- **Dark Surface**: `#2B241D` — deep warm brown, dramatic beats (problem, outro)
- **Text Primary**: `#2B241D` — headings and primary UI text
- **Text Secondary**: `#6B6258` — body copy, labels, helper text
- **Accent Orange**: `#D97B3F` — MemFlow brand orange; CTAs, progress bars, highlights, streaks
- **Surface Light**: `#EBE2D6` — warm beige, card borders and secondary surfaces
- **Success Mint**: `#E7F2E4` — correct answer feedback (BIEN JOUÉ green)
- **Error Coral**: `#F9E3DE` — "Encore"/wrong answer state
- **Pure White**: `#FFFFFF` — modal backgrounds, card fills

## Typography

- **Serif (Lora)**: 600–700. Hero headlines, brand name, cinematic copy. Warm intellectual identity.
  - Logo: "Mem" `#2B241D` + "Flow" `#D97B3F`, both Lora 700
  - Hero size: 96–120px; scene overlays: 56–72px
- **Sans-Serif (Plus Jakarta Sans)**: 400–700. Labels, callouts, data, body copy. Clean and modern.
  - Callout labels: 14–18px, 600 weight, letter-spacing: 0.05em
  - Overlay overlays: 28–40px, 600 weight

## Elevation

- **App cards**: 1px solid `#EBE2D6`, border-radius 16px, no shadows — clean and flat
- **Modals**: White bg, soft shadow `0 8px 32px rgba(43,36,29,0.12)`, border-radius 20px
- **Progress bars**: `#D97B3F` fill on `#EBE2D6` track, 4px height
- **Footage panel**: No border/shadow — sits cleanly on cream background
- **CTA button**: `#D97B3F` fill, white text, border-radius 100px, full-width

## Components

- **Stat Pill Card**: White card, orange icon circle top-left, Lora 600 large number, Plus Jakarta Sans label below (e.g., "14j / de série", "83% / réussite")
- **Collection Card**: White card, emoji icon, bold title Plus Jakarta Sans, orange progress bar, "X à revoir" in orange
- **Session Mode Grid**: 2-col white modal grid, orange circle icon, bold name, short description
- **Callout Pill**: `rgba(217,123,63,0.12)` bg, `1.5px solid #D97B3F` border, orange text — used for mode labels
- **Orange CTA Button**: Full-width rounded `#D97B3F`, white Lora or Plus Jakarta Sans

## Do's and Don'ts

### Do's
- `#FAF6EF` cream as default scene background — never pure white
- Orange `#D97B3F` as the ONLY accent color in overlays
- Lora for all hero text and brand logo; Plus Jakarta Sans for data/labels
- Minimum 80px padding on all scene edges
- `#2B241D` dark for the problem beat — it's a brand color, not a deviation

### Don'ts
- No gradients outside the cream/brown/orange family
- No drop shadows or glow effects on text — use contrast alone
- No animation faster than 0.25s for text entrances — brand is calm and premium
- No pure `#000000` — use `#2B241D` instead
- No text longer than 6 words per line in overlays
