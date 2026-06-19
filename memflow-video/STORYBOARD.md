# Storyboard — MemFlow Launch Film v2 (45s)

**Direction :** Cinématique minimal. Grandes typos Lora centrées, espace négatif, footage dans un device frame flottant (524×779, écran 500×755, ombre douce), grain subtil (opacité 0.05), halo orange très discret. Transitions par mouvement (le device monte/glisse), pas de blur crossfades.

**Palette :** cream #FAF6EF · brun #2B241D · orange texte #CC6F33 / #B45A23 · orange UI #D97B3F
**Musique :** `product_launch.mp3`, volume 0.9, 0–45s.

---

## S1 — OUVERTURE (0–5.8s) — fond cream + grain
Trois statements Lora 96–100px centrés, enchaînés par fondus lents avec drift d'échelle 1.0→1.04 :
« Trop de notes. » (0.3) → « Trop peu de temps. » (1.95) → « *Et si réviser devenait simple ?* » (3.65, italique, tenu).

## S2 — RÉVÉLATION (5.5–11.2s)
Logo MemFlow Lora 130px centré (5.7s) → remonte et rétrécit (y -330, scale 0.45) à 7.0s pendant que le **device monte du bas** (expo.out 1.2s) avec le dashboard (`162657`, ms=0, 5.15s). Caption « Ton espace de révision. » sous le device (8.3s). Micro-flottement y -10 pendant la pose.

## S3 — TROIS MODES (10.9–23.4s) — 4s par mode
À 10.6s le device glisse à droite (x +330) ; mot géant Lora 120px à gauche (x 120–920) :
- 11.3s « **Teste.** » / « Rappel actif. » — QCM `162806` ms=15
- 15.1s « **Retiens.** » / « Mémorisation espacée. » — flashcard `163127` ms=1
- 19.1s « **Écris.** » / « De mémoire pure. » — saisie `163431` ms=13
Footage : crossfade 0.35s dans le frame. Mots : entrée y+60 expo.out, sortie y-50 (remplacement intra-scène).

## S4 — IA (23.2–31.4s)
Le device plonge en bas (22.8s). Statement plein écran « Tes notes deviennent des cartes. » (Lora 96px, 23.5s). À 25.5s le device remonte centré avec l'import CSV (`172022`, ms=0). Pill « ✦ Générées par IA » flotte à droite du device (26.8s, léger yoyo). Caption « Importe. Prévisualise. Révise. » (27.2s).

## S5 — PREUVE (31.5–38.2s)
Pas de device. Trois compteurs Lora 160px #B45A23 centrés en ligne (gap 150px), pop séquentiel + comptage déterministe par `tl.set(innerText)` :
**14** jours de série (31.8) · **83 %** de réussite (32.1) · **436** cartes vues (32.4). Drift d'échelle lent sur la rangée.

## S6 — OUTRO (37.5–45s) — fond #2B241D
Fondu brun (37.5–38.3). Logo 110px (38.6) → tagline (39.2) → CTA « Essaie maintenant → » (39.8) → memflow.one (40.5). Glow respirant fini. Fade au noir 43.5–44.9 (seule sortie autorisée).

---

## Pistes
0 fond cream (0–38.3) · 1 fond outro (37.5–45) · 2 grain (0–45) · 3 v-dashboard + v-import · 4 v-qcm + v-saisie · 5 v-flash · 6 frame-a (5.8–23.4) + frame-b (25.4–31.4) · 8 musique · 10–12 scènes texte.

## Règles tenues
- Frame et vidéo = éléments siblings (pas de video nestée dans un div timé), tweens identiques pour rester solidaires.
- Entrances `gsap.from`/`fromTo` uniquement ; sorties = transitions de scène + outro final.
- Déterministe : compteurs à pas fixes, grain SVG statique, repeats finis.

## Archive
v1 (sidebar + panneau footage, 60s) : `edit/hyperframes/v1-sidebar.html`
