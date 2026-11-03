"""Build the French Memflow tablet user guide as a tagged, linked PDF."""
from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph,
    Spacer, PageBreak, NextPageTemplate, Image, Table, TableStyle, KeepTogether, HRFlowable,
    )
from reportlab.lib.utils import ImageReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "Memflow_Guide_Utilisateur.pdf"
AS = ROOT / "assets"
PAGE_W, PAGE_H = A4
CREAM = colors.HexColor("#FDF9F4")
PAPER = colors.HexColor("#FFFFFF")
SOFT = colors.HexColor("#FBF6EF")
ORANGE = colors.HexColor("#DE7935")
ORANGE_SOFT = colors.HexColor("#FCE9DC")
INK = colors.HexColor("#1E1715")
MUTED = colors.HexColor("#7C6C61")
BORDER = colors.HexColor("#E8DED3")
GREEN = colors.HexColor("#245433")

pdfmetrics.registerFont(TTFont("Outfit", str(Path(__file__).resolve().parents[3] / "assets/fonts/Outfit-Regular.ttf")))
pdfmetrics.registerFont(TTFont("Outfit-Medium", str(Path(__file__).resolve().parents[3] / "assets/fonts/Outfit-Medium.ttf")))
pdfmetrics.registerFont(TTFont("Outfit-Semi", str(Path(__file__).resolve().parents[3] / "assets/fonts/Outfit-SemiBold.ttf")))
pdfmetrics.registerFont(TTFont("Outfit-Bold", str(Path(__file__).resolve().parents[3] / "assets/fonts/Outfit-Bold.ttf")))
pdfmetrics.registerFont(TTFont("Lora", str(Path(__file__).resolve().parents[3] / "assets/fonts/Lora-Regular.ttf")))
pdfmetrics.registerFont(TTFont("Lora-Bold", str(Path(__file__).resolve().parents[3] / "assets/fonts/Lora-Bold.ttf")))
pdfmetrics.registerFontFamily("Outfit", normal="Outfit", bold="Outfit-Bold", italic="Outfit", boldItalic="Outfit-Bold")
pdfmetrics.registerFontFamily("Lora", normal="Lora", bold="Lora-Bold", italic="Lora", boldItalic="Lora-Bold")

styles = getSampleStyleSheet()
styles.add(ParagraphStyle("CoverEyebrow", fontName="Outfit-Semi", fontSize=10, leading=14, textColor=ORANGE, uppercase=True, spaceAfter=14))
styles.add(ParagraphStyle("CoverTitle", fontName="Lora-Bold", fontSize=38, leading=43, textColor=INK, spaceAfter=14))
styles.add(ParagraphStyle("CoverSub", fontName="Outfit", fontSize=17, leading=25, textColor=MUTED))
styles.add(ParagraphStyle("Chapter", fontName="Lora-Bold", fontSize=27, leading=32, textColor=INK, spaceBefore=0, spaceAfter=9, keepWithNext=True))
styles.add(ParagraphStyle("Kicker", fontName="Outfit-Semi", fontSize=9, leading=12, textColor=ORANGE, spaceAfter=7, uppercase=True, keepWithNext=True))
styles.add(ParagraphStyle("Section", fontName="Lora-Bold", fontSize=17, leading=22, textColor=INK, spaceBefore=12, spaceAfter=6, keepWithNext=True))
styles.add(ParagraphStyle("Subsection", fontName="Outfit-Semi", fontSize=12, leading=16, textColor=INK, spaceBefore=9, spaceAfter=4, keepWithNext=True))
styles.add(ParagraphStyle("BodyMF", fontName="Outfit", fontSize=10.1, leading=15.6, textColor=INK, spaceAfter=7))
styles.add(ParagraphStyle("BodySmall", fontName="Outfit", fontSize=9, leading=13, textColor=INK, spaceAfter=4))
styles.add(ParagraphStyle("BulletMF", fontName="Outfit", fontSize=9.8, leading=14.5, textColor=INK, leftIndent=14, firstLineIndent=-9, bulletIndent=0, spaceAfter=4))
styles.add(ParagraphStyle("StepNum", fontName="Lora-Bold", fontSize=16, leading=20, textColor=ORANGE, alignment=TA_CENTER))
styles.add(ParagraphStyle("StepText", fontName="Outfit", fontSize=9.7, leading=14, textColor=INK))
styles.add(ParagraphStyle("Caption", fontName="Outfit", fontSize=8, leading=11, textColor=MUTED, alignment=TA_CENTER, spaceBefore=4, spaceAfter=7))
styles.add(ParagraphStyle("CallTitle", fontName="Outfit-Semi", fontSize=10.2, leading=14, textColor=INK, spaceAfter=3))
styles.add(ParagraphStyle("CallBody", fontName="Outfit", fontSize=9.1, leading=13, textColor=INK))
styles.add(ParagraphStyle("TOC1", fontName="Outfit-Semi", fontSize=11, leading=17, textColor=INK, leftIndent=0, firstLineIndent=0, spaceBefore=5))
styles.add(ParagraphStyle("TOC2", fontName="Outfit", fontSize=9, leading=13, textColor=MUTED, leftIndent=14, firstLineIndent=0))
styles.add(ParagraphStyle("SmallLabel", fontName="Outfit-Semi", fontSize=8, leading=11, textColor=MUTED))

def P(text, style="BodyMF"):
    return Paragraph(text, styles[style])

def bullet(text):
    return P("• " + text, "BulletMF")

def callout(title, body, tone="orange"):
    fill = ORANGE_SOFT if tone == "orange" else SOFT
    stripe = ORANGE if tone == "orange" else MUTED
    t = Table([[P(title, "CallTitle")], [P(body, "CallBody")]], colWidths=[160*mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0,0), (-1,-1), fill), ("BOX", (0,0), (-1,-1), 0.5, BORDER),
        ("LINEBEFORE", (0,0), (0,-1), 3, stripe), ("LEFTPADDING", (0,0), (-1,-1), 12),
        ("RIGHTPADDING", (0,0), (-1,-1), 12), ("TOPPADDING", (0,0), (-1,0), 10),
        ("BOTTOMPADDING", (0,-1), (-1,-1), 10), ("TOPPADDING", (0,1), (-1,1), 0),
    ]))
    return t

def steps(items):
    rows = []
    for i, text in enumerate(items, 1):
        rows.append([P(f"{i:02d}", "StepNum"), P(text, "StepText")])
    t = Table(rows, colWidths=[15*mm, 145*mm], hAlign="LEFT")
    t.setStyle(TableStyle([
        ("VALIGN", (0,0), (-1,-1), "TOP"), ("LINEBELOW", (0,0), (-1,-2), 0.5, BORDER),
        ("LEFTPADDING", (0,0), (-1,-1), 5), ("RIGHTPADDING", (0,0), (-1,-1), 8),
        ("TOPPADDING", (0,0), (-1,-1), 8), ("BOTTOMPADDING", (0,0), (-1,-1), 8),
    ]))
    return t

def figure(filename, caption, max_w=150*mm, max_h=132*mm):
    path = AS / "screenshots" / "annotated" / filename
    im = Image(str(path))
    im._restrictSize(max_w, max_h)
    im.hAlign = "CENTER"
    return [im, P(caption, "Caption")]

def figure_pair(items):
    cells = []
    for filename, caption in items:
        im = Image(str(AS / "screenshots" / "annotated" / filename))
        im._restrictSize(72*mm, 58*mm)
        im.hAlign = "CENTER"
        cells.append([im, P(caption, "Caption")])
    t = Table([[cells[0], cells[1]]], colWidths=[79*mm, 79*mm], hAlign="LEFT")
    t.setStyle(TableStyle([("VALIGN",(0,0),(-1,-1),"TOP"), ("LEFTPADDING",(0,0),(-1,-1),2),
        ("RIGHTPADDING",(0,0),(-1,-1),2), ("TOPPADDING",(0,0),(-1,-1),5)]))
    return t

class GuideDoc(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(filename, pagesize=A4, leftMargin=25*mm, rightMargin=25*mm,
                         topMargin=22*mm, bottomMargin=20*mm, title="Guide d'utilisation Memflow",
                         author="Memflow", subject="Guide d'utilisation de Memflow sur tablette Android")
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height,
                      leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0, id="normal")
        self.addPageTemplates([
            PageTemplate(id="cover", frames=frame, onPage=cover),
            PageTemplate(id="main", frames=frame, onPage=self.draw_page),
        ])
        self._toc_counter = 0

    def draw_page(self, canvas, doc):
        canvas.saveState()
        canvas.setFillColor(CREAM)
        canvas.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
        if doc.page > 1:
            canvas.setStrokeColor(BORDER)
            canvas.setLineWidth(.55)
            canvas.line(25*mm, PAGE_H-14*mm, PAGE_W-25*mm, PAGE_H-14*mm)
            canvas.setFont("Outfit-Semi", 8)
            canvas.setFillColor(ORANGE)
            canvas.drawString(25*mm, PAGE_H-11*mm, "MEMFLOW")
            canvas.setFont("Outfit", 8)
            canvas.setFillColor(MUTED)
            canvas.drawRightString(PAGE_W-25*mm, PAGE_H-11*mm, "GUIDE D’UTILISATION · TABLETTE ANDROID")
            canvas.line(25*mm, 14*mm, PAGE_W-25*mm, 14*mm)
            canvas.setFont("Outfit", 8)
            canvas.drawString(25*mm, 9*mm, "Memflow · Version 2.4.0 · 3 novembre 2026")
            canvas.drawRightString(PAGE_W-25*mm, 9*mm, str(doc.page))
        canvas.restoreState()

    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph) and flowable.style.name == "Chapter":
            self._toc_counter += 1
            key = f"chapter-{self._toc_counter}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(flowable.getPlainText(), key, 0, closed=False)
            flowable._bookmark_key = key

def chapter(num, title, subtitle):
    return [P(f"CHAPITRE {num:02d} · {subtitle}", "Kicker"), P(f'<a name="chapter-start-{num}"/> {title}', "Chapter")]

def cover(canvas, doc):
    canvas.saveState()
    canvas.setFillColor(CREAM)
    canvas.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)
    canvas.setFillColor(INK)
    canvas.rect(0, PAGE_H-11*mm, PAGE_W, 11*mm, fill=1, stroke=0)
    canvas.setFillColor(ORANGE)
    canvas.rect(0, 0, 8*mm, PAGE_H, fill=1, stroke=0)
    canvas.setFillColor(ORANGE_SOFT)
    canvas.circle(PAGE_W+17*mm, 52*mm, 70*mm, fill=1, stroke=0)
    canvas.restoreState()

def build_story():
    story = []
    logo = AS / "branding" / "memflow.png"
    img = Image(str(logo), width=23*mm, height=23*mm)
    img.hAlign = "LEFT"
    story += [Spacer(1, 25*mm), img, Spacer(1, 17*mm),
              P("GUIDE OFFICIEL · ANDROID TABLETTE", "CoverEyebrow"),
              P("Guide<br/>d’utilisation", "CoverTitle"),
              P("Apprendre avec méthode, retrouver ses cartes, suivre sa progression.", "CoverSub"),
              Spacer(1, 38*mm), HRFlowable(width="100%", thickness=1, color=BORDER), Spacer(1, 6*mm),
              P("Édition 2.4.0 · 3 novembre 2026", "BodySmall"),
              P("Conçu pour Memflow sur tablette Android", "BodySmall"), NextPageTemplate("main"), PageBreak()]

    story += [P("Repères", "Kicker"), P("Sommaire", "Chapter"),
              P("Choisissez une rubrique pour accéder directement à son chapitre.", "BodyMF"), Spacer(1, 5*mm)]
    toc_titles = [
        "Découvrir Memflow", "Premiers pas", "Se repérer sur tablette", "Collections et cartes",
        "Réviser ses cartes", "Importer et exporter", "Suivre sa progression", "Profil et paramètres",
        "Tutoriels", "Résoudre un problème", "Données et compte", "Mots utiles",
    ]
    toc_data = [[P(f'<link href="#chapter-{i}">{i:02d}  {name}</link>', "TOC1")] for i, name in enumerate(toc_titles, 1)]
    toc_table = Table(toc_data, colWidths=[160*mm], hAlign="LEFT")
    toc_table.setStyle(TableStyle([("LINEBELOW", (0,0), (-1,-2), .45, BORDER),
        ("LEFTPADDING",(0,0),(-1,-1),2), ("TOPPADDING",(0,0),(-1,-1),6),
        ("BOTTOMPADDING",(0,0),(-1,-1),6)]))
    story += [toc_table, Spacer(1, 7*mm), callout("À propos de cette édition", "Ce guide décrit Memflow 2.4.0 sur une tablette Android. Les libellés cités reprennent ceux de l’interface observée. La mise en page peut différer légèrement selon la taille de l’écran et la version d’Android."), PageBreak()]

    story += chapter(1, "Découvrir Memflow", "L’essentiel")
    story += [P("Memflow est une application de cartes de révision. Elle aide à organiser des questions en collections et en decks, puis à les revoir au bon moment. Une session peut présenter une question à choix, une flashcard, une saisie ou un exercice à trous selon le contenu disponible."),
              P("L’écran d’accueil met en évidence les cartes à revoir, l’activité récente et les collections. Les statistiques donnent un aperçu de la régularité et de la réussite. L’application conserve les modifications localement et les synchronise avec le compte lorsque le réseau est disponible."),
              P("À qui s’adresse Memflow ?", "Section"), bullet("Aux personnes qui veulent transformer un cours ou un sujet en questions et réponses."), bullet("Aux personnes qui révisent par petites sessions et souhaitent suivre leur progression."), bullet("Aux personnes qui utilisent plusieurs appareils et veulent retrouver leurs cartes après connexion et synchronisation."),
              Spacer(1, 3*mm), callout("À retenir", "Une réponse donnée pendant une révision met à jour l’échéance de la carte. Prenez le temps de choisir le bouton qui correspond à votre niveau de rappel.") , PageBreak()]

    story += chapter(2, "Premiers pas", "Compte et démarrage")
    story += [P("Au premier lancement, Memflow demande de se connecter ou de créer un compte. La connexion permet de synchroniser les données entre appareils. L’application peut ensuite afficher les données locales déjà présentes même en l’absence de réseau."),
              P("Créer un compte ou se connecter", "Section"),
              steps(["Sur l’écran MemFlow, choisissez l’action de connexion ou le lien de création de compte.", "Pour un nouveau compte, saisissez votre nom, votre adresse email et un mot de passe. Confirmez la majorité et l’acceptation des conditions d’utilisation.", "Validez le formulaire. Si une confirmation par email est demandée, ouvrez le message reçu puis revenez dans l’application.", "Pour un compte existant, saisissez votre adresse email et votre mot de passe, puis connectez-vous."]),
              P("Mot de passe oublié", "Section"), P("Depuis l’écran de connexion, choisissez « Mot de passe oublié », vérifiez l’adresse proposée puis appuyez sur « Envoyer ». Un lien de réinitialisation est envoyé par email. Ouvrez ce lien pour choisir un nouveau mot de passe."),
              callout("Connexion et hors ligne", "La connexion sert à retrouver et synchroniser les données. Si vous êtes déjà connecté, Memflow peut démarrer sur les données conservées localement sans connexion Internet.", "neutral"), PageBreak()]

    story += chapter(3, "Se repérer sur tablette", "Interface")
    story += [P("Sur la tablette de référence, les quatre destinations restent visibles dans le rail latéral : « Accueil », « Stats », « Importer » et « Profil ». Appuyez sur une destination pour changer de section. Sur un écran moins large, ces destinations peuvent apparaître dans une barre en bas."),
              P("Depuis l’accueil, appuyez sur une collection pour consulter ses decks. Dans un deck, la liste de cartes se charge au fil du défilement. Une flèche de retour permet de revenir à l’écran précédent. Faites défiler verticalement les pages longues."),
              P("L’accueil rassemble le bouton « Étudier maintenant », la recherche et les collections. La loupe filtre les collections par nom. Appuyez sur l’icône d’actualisation pour demander une synchronisation depuis l’accueil ou les statistiques."),
              P("Affichage accessible", "Section"), P("Memflow suit les préférences Android de taille du texte et de réduction des animations. Lorsque les caractères sont agrandis, certaines cartes qui s’affichent côte à côte passent en colonne pour rester lisibles."),
              Spacer(1, 2*mm)]
    story += figure("accueil-demo-annote.png", "Accueil Memflow sur tablette Android. Compte fictif de démonstration ; 1. navigation  2. recherche  3. démarrage d’une session.", 145*mm, 132*mm)
    story += [PageBreak()]

    story += chapter(4, "Collections et cartes", "Organisation")
    story += [P("Les collections regroupent des decks ; les decks regroupent les cartes. La page d’accueil affiche le nombre de cartes terminées, les cartes à revoir et une barre de progression pour chaque collection."),
              P("Trouver une collection", "Section"), steps(["Appuyez sur le champ « Rechercher une collection » sur l’accueil.", "Saisissez quelques lettres du nom. La liste se filtre au fur et à mesure.", "Appuyez sur la collection voulue pour afficher ses decks et son avancement."]),
              P("Dans le détail d’une collection, vous pouvez lancer une session sur l’ensemble de la collection ou choisir un deck. La liste des decks peut être triée. Le menu « Options du deck » donne accès à « Voir les cartes », à la désactivation et à la suppression du deck."),
              callout("Suppression", "La suppression d’une collection ou d’un deck est définitive et comprend ses cartes. Un dialogue de confirmation précise l’étendue de la suppression. Annulez si vous avez le moindre doute."),
              P("Consulter les cartes d’un deck", "Section"), P("Dans la collection, appuyez sur « Options du deck », puis sur « Voir les cartes ». Faites défiler la liste pour parcourir les questions et leurs réponses. Memflow charge les cartes par pages ; tirez la liste vers le bas pour l’actualiser. Utilisez l’icône de suppression d’une carte uniquement après avoir vérifié son contenu ; une confirmation est demandée."), PageBreak(),
              P("Collections et progression", "Kicker"), P("Lire le détail d’une collection", "Chapter"),
              P("La vue Informatique ci-dessous montre le nombre total de cartes, les cartes faites et celles à revoir. Chaque deck affiche son avancement ; appuyez sur un deck pour choisir un mode de session.", "BodyMF")]
    story += figure("collection-demo-annote.png", "Collection Informatique du compte fictif de démonstration : 68 cartes dans 4 decks. 1. total  2. avancement du deck  3. accès à l’étude.", 145*mm, 172*mm)
    story += [PageBreak(), P("Cartes d’un deck", "Kicker"), P("Parcourir le contenu", "Chapter"),
              P("Le menu « Options du deck » ouvre la liste des cartes. Chaque ligne présente la question et sa réponse. La capture ci-dessous montre les premières cartes du deck Algorithmique.", "BodyMF")]
    story += figure("cartes-algorithmique-annote.png", "Liste réelle des 17 cartes d’Algorithmique. L’icône rouge ouvre une confirmation avant suppression.", 145*mm, 175*mm)
    story += [PageBreak()]

    story += chapter(5, "Réviser ses cartes", "Sessions d’étude")
    story += [P("Depuis l’accueil, « Étudier maintenant » lance une session sur les cartes dues. Depuis une collection ou un deck, la session porte sur ce périmètre. Sur la tablette, le choix du mode apparaît dans une boîte de dialogue. Vous y trouverez « Adaptatif » et les modes compatibles avec les cartes sélectionnées."),
              P("Six modes sont prévus : QCM, Vrai / Faux, Flashcard, Flashcard inversée, Saisie libre et Texte à trous. Un mode apparaît lorsque les données de la carte permettent de l’utiliser. Le mode « Adaptatif » suit la progression enregistrée pour chaque carte."),
              P("Déroulement d’une carte", "Section"), steps(["Lisez la question et réfléchissez avant de révéler ou saisir la réponse.", "Selon le mode, choisissez une réponse, retournez la carte, écrivez votre réponse ou complétez les trous.", "Comparez votre réponse à la correction affichée.", "Évaluez votre rappel avec « Encore », « Difficile », « Correct » ou « Facile ».", "Passez à la carte suivante. À la fin, consultez le bilan de session."]),
              P("Les modes corrigés automatiquement proposent une évaluation en fonction de la réponse. Vous pouvez choisir une autre évaluation si elle reflète mieux votre souvenir."),
              P("Le bilan récapitule les cartes vues, les résultats et le taux de réussite. S’il reste des erreurs, vous pouvez les revoir. Les boutons permettent de revenir à la collection, de refaire une session ou d’ouvrir l’accueil."),
              callout("Comment les réponses modifient le calendrier", "« Encore » programme un nouvel essai après quelques minutes ; « Difficile » raccourcit l’intervalle ; « Correct » et « Facile » espacent davantage les révisions. Les dates exactes évoluent selon l’historique de la carte.", "neutral"), PageBreak(),
              P("Choisir un mode", "Kicker"), P("Des formats adaptés aux cartes", "Chapter"),
              P("Memflow indique le nombre de cartes compatibles avec chaque mode. La disponibilité varie selon les champs renseignés dans les cartes du deck.", "BodyMF")]
    story += figure("modes-session-annote.png", "Sélecteur de modes ouvert depuis un deck du compte de démonstration. 1. Adaptatif  2. choix multiple  3. modes de saisie.", 145*mm, 175*mm)
    story += [PageBreak(), P("Répondre puis s’autoévaluer", "Kicker"), P("Une carte en pratique", "Chapter"),
              P("Après votre réponse, l’application affiche la correction et propose quatre évaluations du rappel. Choisissez celle qui correspond à votre effort de mémoire.", "BodyMF")]
    story += figure("correction-qcm-annote.png", "Correction d’une question à choix multiples et boutons d’autoévaluation. Capture réelle de la session démo.", 120*mm, 180*mm)
    story += [PageBreak()]

    story += chapter(6, "Importer et exporter", "Fichiers")
    story += [P("L’onglet « Importer » accepte des fichiers CSV ou TXT séparés par point-virgule, virgule ou tabulation, avec ou sans ligne d’en-tête. Sélectionnez un fichier pour voir l’aperçu et les erreurs détectées avant toute restauration."),
              P("Restaurer un fichier", "Section"), steps(["Ouvrez « Importer » dans le rail latéral.", "Appuyez sur « Importer un fichier CSV » puis choisissez un fichier CSV ou TXT dans le sélecteur Android.", "Vérifiez l’aperçu des cartes et les éventuelles erreurs. Si le fichier est illisible, choisissez un autre fichier ou corrigez son format.", "Appuyez sur « Restaurer » et lisez le dialogue de confirmation.", "Confirmez pour ajouter les cartes. Memflow affiche le nombre de cartes importées et revient à l’accueil."]),
              callout("Avant de confirmer", "La restauration ajoute les cartes au contenu local existant ; elle ne supprime pas les cartes déjà présentes. Des doublons sont possibles. Pour retrouver une sauvegarde complète, l’application recommande de restaurer sur une base vide."),
              P("Ressources complémentaires", "Section"),
              P("Dans « Options avancées », vous pouvez télécharger le template CSV, sauvegarder toutes vos cartes, consulter le prompt CSV Memflow, le copier ou le télécharger au format .md. Le prompt est un texte d’aide à utiliser avec un outil externe ; Memflow ne génère pas lui-même le fichier avec une IA."),
              P("Pour démarrer un fichier compatible, téléchargez le template. Pour conserver une copie de toutes les cartes, choisissez « Sauvegarder toutes mes cartes ». Le format conseillé distingue notamment la collection, le deck, la question, la réponse correcte, les réponses erronées et les champs complémentaires."), PageBreak(),
              P("Repères visuels", "Kicker"), P("Importer et préparer un fichier", "Chapter"),
              P("Les captures montrent l’aperçu d’un fichier pédagogique fictif, puis les commandes complémentaires disponibles dans « Options avancées ».", "BodyMF")]
    story += figure("import-apercu-demo-annote.png", "Aperçu réel du CSV démo : 153 cartes détectées, aucune ligne invalide. La restauration n’est pas relancée depuis cet aperçu.", 145*mm, 145*mm)
    story += [PageBreak(), P("Options avancées", "Kicker"), P("Préparer d’autres fichiers", "Chapter"),
              P("Téléchargez un modèle CSV, créez une sauvegarde de vos cartes ou consultez le prompt d’aide au formatage.", "BodyMF")]
    story += figure("import-avance-demo-annote.png", "Deux commandes des options avancées : modèle CSV et sauvegarde de toutes les cartes.", 145*mm, 80*mm)
    story += [P("Créer un modèle ou une sauvegarde", "Section"),
              steps(["Dans « Importer », ouvrez « Options avancées ».",
                     "Appuyez sur « Télécharger le template CSV » pour partir d’une structure prête à remplir, ou sur « Sauvegarder toutes mes cartes » pour exporter votre collection de cartes."]), PageBreak()]
    story += chapter(7, "Suivre sa progression", "Statistiques")
    story += [P("L’écran « Stats » présente le nombre de jours de série, les cartes vues et le taux de réussite. Plus bas, des graphiques montrent l’activité sur les 14 derniers jours et l’évolution récente de la réussite."),
              P("Les sections de progression détaillent les niveaux, les collections et les modes d’étude. Une rubrique met en évidence les cartes les plus difficiles lorsque des données sont disponibles. Les jours sans révision restent vides dans le graphique d’activité."),
              P("Les statistiques se mettent à jour au fil des sessions. Tirez l’écran vers le bas ou appuyez sur l’icône « Synchroniser » pour actualiser les données. En cas d’échec de chargement, appuyez sur « Réessayer »."),
              callout("Lecture des indicateurs", "Le taux de réussite résume les réponses enregistrées. Il ne constitue pas une note globale : regardez aussi la fréquence d’étude, les modes de rappel et les cartes difficiles pour comprendre votre progression.", "neutral"), PageBreak(),
              P("Progression observée", "Kicker"), P("Une activité enregistrée sur plusieurs vues", "Chapter"),
              P("Cette capture présente les indicateurs mis à jour après une session réelle de 12 cartes dans le compte de démonstration. L’historique couvre uniquement la journée de capture ; les jours antérieurs restent vides.", "BodyMF")]
    story += figure("statistiques-demo-annote.png", "Statistiques après une session sur tablette : activité du jour et évolution récente de la réussite. Données du compte fictif de démonstration.", 145*mm, 150*mm)
    story += [PageBreak()]

    story += chapter(8, "Profil et paramètres", "Compte et personnalisation")
    story += [P("Dans « Profil », vous pouvez consulter l’état de synchronisation, déclencher une synchronisation, exporter les cartes au format CSV, régler votre objectif quotidien, consulter les documents légaux et vous déconnecter."),
              P("Objectif quotidien", "Section"), P("Dans le groupe « Révision », appuyez sur « Objectif quotidien », saisissez un nombre de cartes compris entre 1 et 999 puis choisissez « Enregistrer ». Ce nombre sert de repère quotidien."),
              P("Paramètres du compte", "Section"), P("Ouvrez « Paramètres du compte » pour modifier le nom d’affichage, l’adresse email ou le mot de passe. Un changement d’adresse email nécessite une confirmation par email. Le mot de passe doit contenir au moins six caractères et être saisi deux fois."),
              P("Cartes par session", "Section"), P("Dans les paramètres, choisissez « Cartes par session », saisissez un nombre de 1 à 999 puis appuyez sur « Enregistrer ». Cette valeur fixe la limite d’une session."),
              Spacer(1, 3*mm)]
    story += figure("profil-demo-annote.png", "Profil du compte fictif Camille Martin. L’adresse email est masquée. 1. compte  2. objectif quotidien  3. synchronisation et export.", 145*mm, 125*mm)
    story += [PageBreak(), P("Réglages du compte", "Kicker"), P("Les paramètres en un coup d’œil", "Chapter"),
              P("Le panneau « Paramètres » regroupe la modification du nom, de l’adresse email et du mot de passe, ainsi que la limite de cartes par session. L’adresse email du compte démo est masquée dans cette capture.", "BodyMF")]
    story += figure("parametres-demo-annote.png", "Paramètres du compte de démonstration. L’adresse email est masquée. 1. identité du compte  2. limite de cartes par session.", 145*mm, 116*mm)
    story += [PageBreak()]

    story += chapter(9, "Tutoriels", "Parcours guidés")
    story += [P("Tutoriel 1 · Préparer une session", "Section"),
              steps(["Depuis l’accueil, repérez le nombre de cartes à revoir.", "Appuyez sur « Étudier maintenant » pour une session générale, ou ouvrez une collection puis un deck pour cibler vos révisions.", "Choisissez « Adaptatif » pour laisser Memflow sélectionner le mode de chaque carte. Les modes indisponibles ne sont pas proposés.", "Répondez à chaque carte, consultez la correction puis évaluez votre rappel.", "À la fin, consultez le bilan. Relancez les erreurs si vous souhaitez les retravailler."]),
              P("Résultat attendu : chaque évaluation est prise en compte dans l’échéance de révision et le bilan affiche les résultats de la session."),
              P("Tutoriel 2 · Importer un fichier", "Section"),
              steps(["Préparez un CSV ou un fichier texte contenant les cartes, séparées par virgules, points-virgules ou tabulations.", "Ouvrez l’onglet « Importer » puis choisissez « Importer un fichier CSV ».", "Sélectionnez le fichier et vérifiez l’aperçu. Si une erreur apparaît, corrigez le fichier avant de recommencer.", "Choisissez « Restaurer », relisez le message indiquant que les cartes seront ajoutées, puis confirmez.", "Retournez à l’accueil et vérifiez la collection importée."]),
              callout("Conseil de prudence", "Si vous restaurez une sauvegarde complète, vérifiez le contenu local avant l’import afin d’éviter les doublons. Ne confirmez jamais une restauration dont vous ne reconnaissez pas le fichier."), PageBreak(),
              P("Résultat d’une session", "Kicker"), P("Vérifier le bilan", "Chapter"),
              P("Le bilan présente la précision objective, le nombre de cartes vues et la répartition des évaluations. Dans cette session de démonstration, les 12 réponses ont été notées « Correct » ; les résultats évoluent selon les réponses de chaque personne.", "BodyMF")]
    story += figure("bilan-session-annote.png", "Bilan authentique d’une session de 12 cartes dans le deck Algorithmique du compte démo.", 120*mm, 175*mm)
    story += [PageBreak()]

    story += chapter(10, "Résoudre un problème", "Aide pratique")
    story += [P("La synchronisation reste en attente", "Section"), P("Symptôme : le profil indique des modifications en attente ou « Synchronisation impossible ». Vérifiez que la tablette dispose d’une connexion Internet, puis appuyez sur « Synchroniser maintenant ». Les données locales restent disponibles hors ligne. Réessayez lorsque le réseau revient."),
              P("Le fichier d’import est illisible", "Section"), P("Vérifiez l’extension CSV ou TXT et le séparateur. L’import accepte les séparateurs virgule, point-virgule et tabulation, avec ou sans en-tête. Choisissez un autre fichier si l’aperçu signale une erreur."),
              P("Je ne trouve pas un mode d’étude", "Section"), P("Le mode peut être absent si le contenu de la carte ne permet pas une correction fiable dans ce format. Choisissez « Adaptatif » ou un autre mode proposé."),
              P("Les statistiques ne se chargent pas", "Section"), P("Dans « Stats », utilisez « Réessayer ». Si le problème persiste, vérifiez le réseau et relancez une synchronisation depuis le profil."),
              P("Questions fréquentes", "Section"),
              P("Puis-je réviser sans réseau ?", "Subsection"), P("Oui, les données locales restent accessibles. Les changements en attente sont synchronisés à la reconnexion."),
              P("La restauration remplace-t-elle mes cartes ?", "Subsection"), P("Non. Elle ajoute des cartes aux données locales. Les cartes existantes ne sont pas supprimées et des doublons peuvent apparaître."),
              P("Comment demander la suppression de mon compte ?", "Subsection"), P("Dans « Profil », choisissez « Demander la suppression de mon compte », puis « Continuer ». Un email prérempli s’ouvre vers le support ; la demande est traitée manuellement. Cette opération n’a pas été lancée pendant la préparation de ce guide."),
              P("Puis-je changer le thème ?", "Subsection"), P("La version observée propose un thème clair. Aucun réglage de thème n’est disponible dans les paramètres."), PageBreak()]

    story += chapter(11, "Données et compte", "Conservation")
    story += [P("Memflow enregistre d’abord vos changements sur l’appareil, puis les synchronise quand le réseau est disponible. Le profil indique si les données sont synchronisées, si une synchronisation est en cours, si des modifications restent en attente ou si une erreur s’est produite."),
              P("Avant de changer d’appareil", "Section"), steps(["Ouvrez « Profil » et regardez l’état de synchronisation.", "Si des changements sont en attente, connectez la tablette à Internet puis appuyez sur « Synchroniser maintenant ».", "Attendez l’état « Synchronisé » avant de vous déconnecter ou de changer d’appareil.", "Sur le nouvel appareil, connectez-vous au même compte et laissez la synchronisation se terminer."]),
              P("La déconnexion retire les données du compte de l’appareil. Assurez-vous que les changements sont synchronisés avant de vous déconnecter. Pour conserver une copie de vos cartes, utilisez « Sauvegarder toutes mes cartes » ou « Exporter les cartes en CSV » avant de quitter la session."),
              P("Demander la suppression du compte", "Section"), P("Dans « Profil », choisissez « Demander la suppression de mon compte », puis confirmez en appuyant sur « Continuer ». L’application ouvre un email prérempli vers le support. La suppression est traitée manuellement ; le bouton ne supprime pas immédiatement le compte."),
              callout("Tablette partagée", "La déconnexion efface les données locales de l’utilisateur. Vérifiez que la synchronisation est terminée et que vos cartes importantes ont une sauvegarde avant de vous déconnecter.") , PageBreak()]

    story += chapter(12, "Mots utiles", "Glossaire")
    rows = [
        [P("Terme", "SmallLabel"), P("Sens dans Memflow", "SmallLabel")],
        [P("Carte", "BodySmall"), P("Une question, sa réponse et, selon le cas, des indices ou des réponses alternatives.", "BodySmall")],
        [P("Deck", "BodySmall"), P("Un ensemble de cartes regroupées dans une collection.", "BodySmall")],
        [P("Collection", "BodySmall"), P("Un groupe de decks organisé autour d’un sujet.", "BodySmall")],
        [P("Session", "BodySmall"), P("Une séquence de cartes étudiées en une fois, limitée par le réglage « Cartes par session ».", "BodySmall")],
        [P("Adaptatif", "BodySmall"), P("Mode qui choisit pour chaque carte le type de question adapté à sa progression et à ses données.", "BodySmall")],
        [P("Synchronisation", "BodySmall"), P("Mise en cohérence des modifications locales avec les données du compte lorsque le réseau est disponible.", "BodySmall")],
        [P("CSV", "BodySmall"), P("Format de fichier tabulaire pouvant contenir les champs des cartes et être ouvert dans un tableur.", "BodySmall")],
    ]
    table = Table(rows, colWidths=[38*mm, 122*mm], repeatRows=1, hAlign="LEFT")
    table.setStyle(TableStyle([("BACKGROUND", (0,0),(-1,0), ORANGE_SOFT), ("GRID",(0,0),(-1,-1),.45,BORDER),
        ("VALIGN",(0,0),(-1,-1),"TOP"), ("LEFTPADDING",(0,0),(-1,-1),9), ("RIGHTPADDING",(0,0),(-1,-1),9),
        ("TOPPADDING",(0,0),(-1,-1),8), ("BOTTOMPADDING",(0,0),(-1,-1),8)]))
    story += [table, Spacer(1, 12*mm), P("Source et version", "Section"),
              P("Guide établi à partir de Memflow 2.4.0 observé le 3 novembre 2026 sur une tablette Samsung SM-X406B sous Android 16. Les captures sont des captures ADB authentiques du compte fictif de démonstration Camille Martin ; l’adresse email personnelle utilisée pour ce compte a été masquée. Le jeu importé contient 153 cartes pédagogiques fictives. Une session de 12 cartes a été effectuée pour vérifier le parcours de révision et alimenter les statistiques du jour."),
              callout("Repère", "Les libellés et écrans de ce guide correspondent à Memflow 2.4.0 sur Android. Consultez « Version app » dans votre profil pour vérifier la version installée.", "neutral")]
    return story

def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = GuideDoc(str(OUT))
    doc.build(build_story())
    print(f"Created {OUT}")

if __name__ == "__main__":
    main()
