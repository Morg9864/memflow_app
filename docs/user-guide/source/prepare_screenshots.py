"""Prepare privacy-safe figures from genuine ADB captures of the demo account."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ORIGINALS = ROOT / "assets" / "screenshots" / "originals"
ANNOTATED = ROOT / "assets" / "screenshots" / "annotated"
TMP = Path("/tmp")
FONT = Path(__file__).resolve().parents[3] / "assets" / "fonts" / "Outfit-Medium.ttf"

ORIGINALS.mkdir(parents=True, exist_ok=True)
ANNOTATED.mkdir(parents=True, exist_ok=True)


def capture(source: str, name: str, redact_email: bool = False) -> Image.Image:
    """Copy one real tablet screenshot, masking only the account email field."""
    image = Image.open(TMP / source).convert("RGB")
    if redact_email:
        draw = ImageDraw.Draw(image)
        font = ImageFont.truetype(str(FONT), 25)
        # The field is a personal email supplied for the demo account. Keep the
        # fictional display name and replace only the address with a clear mask.
        if name == "parametres-compte-demo.png":
            draw.rectangle((340, 305, 1090, 424), fill="#FFFFFF")
            draw.text((358, 320), "Adresse email", font=font, fill="#342A26")
            draw.text((358, 360), "adresse masquée", font=font, fill="#342A26")
        else:
            draw.rectangle((286, 222, 650, 270), fill="#FFFFFF")
            draw.text((297, 229), "adresse masquée", font=font, fill="#342A26")
    image.save(ORIGINALS / name, format="PNG", optimize=True)
    return image


def annotate(image: Image.Image, name: str, points: list[tuple[int, int, int]]) -> None:
    out = image.copy()
    draw = ImageDraw.Draw(out)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
    for number, x, y in points:
        radius = 23
        draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill="#DE7935", outline="#FFFFFF", width=5)
        label = str(number)
        bounds = draw.textbbox((0, 0), label, font=font)
        draw.text((x-(bounds[2]-bounds[0])/2, y-(bounds[3]-bounds[1])/2-2), label, font=font, fill="#FFFFFF")
    # Remove Android's status and navigation bars from document figures while
    # retaining the untouched, full-resolution capture in originals/.
    crop_boxes = {
        "accueil-demo-annote.png": (0, 45, 1320, 1450),
        "modes-session-annote.png": (40, 480, 1280, 1640),
        "import-apercu-demo-annote.png": (250, 45, 1170, 1530),
        "import-avance-demo-annote.png": (290, 1390, 1153, 1805),
        "statistiques-demo-annote.png": (0, 45, 1320, 1260),
        "profil-demo-annote.png": (120, 45, 1320, 1230),
        "parametres-demo-annote.png": (120, 45, 1230, 750),
        "bilan-session-annote.png": (80, 60, 1240, 1160),
    }
    out = out.crop(crop_boxes.get(name, (0, 45, 1320, 2089)))
    out.save(ANNOTATED / name, format="PNG", optimize=True)


# Retire every legacy image so no blurred owner-account screenshot remains in
# the publishable screenshot folders.
for folder in (ORIGINALS, ANNOTATED):
    for old_image in folder.glob("*.png"):
        old_image.unlink()

captures = {
    "home": capture("memflow-demo-home-poststudy.png", "accueil-compte-demo.png"),
    "collection": capture("memflow-demo-collection-poststudy.png", "collection-informatique-demo.png"),
    "cards": capture("memflow-demo-card-list.png", "cartes-algorithmique-demo.png"),
    "modes": capture("memflow-demo-modes.png", "modes-session-demo.png"),
    "question": capture("memflow-demo-study-qcm.png", "session-qcm-question-demo.png"),
    "feedback": capture("memflow-demo-study-feedback.png", "session-qcm-correction-demo.png"),
    "summary": capture("memflow-demo-summary.png", "session-bilan-demo.png"),
    "stats": capture("memflow-demo-stats.png", "statistiques-demo.png"),
    "import": capture("memflow-demo-import-preview.png", "import-apercu-demo.png"),
    "advanced": capture("memflow-demo-import-advanced.png", "import-options-avancees-demo.png"),
    "profile": capture("memflow-demo-profile.png", "profil-compte-demo.png", redact_email=True),
    "settings": capture("memflow-demo-settings.png", "parametres-compte-demo.png", redact_email=True),
}

annotation_map = {
    "home": ("accueil-demo-annote.png", [(1, 58, 80), (2, 188, 735), (3, 225, 495)]),
    "collection": ("collection-demo-annote.png", [(1, 1030, 180), (2, 430, 920), (3, 1050, 2020)]),
    "cards": ("cartes-algorithmique-annote.png", [(1, 1080, 370), (2, 1125, 322)]),
    "modes": ("modes-session-annote.png", [(1, 230, 770), (2, 220, 1010), (3, 610, 1480)]),
    "question": ("question-qcm-annote.png", [(1, 1100, 164), (2, 180, 601), (3, 100, 1090)]),
    "feedback": ("correction-qcm-annote.png", [(1, 1230, 1685), (2, 970, 1898)]),
    "summary": ("bilan-session-annote.png", [(1, 1115, 270), (2, 1110, 500), (3, 1120, 750)]),
    "stats": ("statistiques-demo-annote.png", [(1, 380, 235), (2, 1100, 510), (3, 1100, 1020)]),
    "import": ("import-apercu-demo-annote.png", [(1, 1080, 400), (2, 1080, 650)]),
    "advanced": ("import-avance-demo-annote.png", [(1, 1080, 1560), (2, 1080, 1650), (3, 1080, 1750)]),
    "profile": ("profil-demo-annote.png", [(1, 1000, 400), (2, 1000, 900), (3, 1010, 1035)]),
    "settings": ("parametres-demo-annote.png", [(1, 980, 270), (2, 930, 660)]),
}

for key, (name, points) in annotation_map.items():
    annotate(captures[key], name, points)

print(f"Préparé {len(captures)} captures authentiques du compte démo; l'adresse email a été masquée.")
