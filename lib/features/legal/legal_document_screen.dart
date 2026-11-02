import 'package:flutter/material.dart';

import '../../app/app_version.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ui.dart';

/// Legal documents shown in the Android application.
const currentTermsVersion = '2026-11-02';

bool needsLegalAcceptance(Map<String, dynamic>? metadata) =>
    metadata?['accepted_terms_version'] != currentTermsVersion ||
    metadata?['adult_attested_at'] is! String ||
    (metadata?['adult_attested_at'] as String).isEmpty;

enum LegalDocument {
  privacy,
  terms,
  notices,
  cookies;

  static LegalDocument fromSlug(String slug) {
    return LegalDocument.values.firstWhere(
      (doc) => doc.slug == slug,
      orElse: () => LegalDocument.privacy,
    );
  }

  String get slug => switch (this) {
    LegalDocument.privacy => 'privacy',
    LegalDocument.terms => 'terms',
    LegalDocument.notices => 'notices',
    LegalDocument.cookies => 'cookies',
  };

  String get title => switch (this) {
    LegalDocument.privacy => 'Politique de confidentialité',
    LegalDocument.terms => "Conditions d'utilisation",
    LegalDocument.notices => 'Mentions légales',
    LegalDocument.cookies => 'Cookies et stockage',
  };
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Deep-linked: nothing to pop, so the AppBar would show no back button.
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        leading: canPop
            ? null
            : IconButton(
                tooltip: 'Retour',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => popOrGo(context, '/profile'),
              ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SelectionArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                children: [
                  Text(
                    'Version du 2 novembre 2026',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final section in _sectionsFor(document))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            header: true,
                            child: Text(
                              section.$1,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            section.$2,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<(String, String)> _sectionsFor(LegalDocument document) {
    switch (document) {
      case LegalDocument.privacy:
        return const [
          (
            'Responsable du traitement et contact',
            'Morgan Phemba, personne physique établie en Belgique. Contact : contact@morganphemba.be. Adresse postale de contact à compléter avant publication.',
          ),
          (
            'Personnes concernées et âge',
            'Memflow est réservé aux personnes âgées de 18 ans ou plus. La déclaration de majorité est enregistrée avec sa date; il ne s’agit pas d’une vérification d’identité. Si vous avez moins de 18 ans, n’utilisez pas le service et contactez-nous pour demander la suppression d’un compte créé par erreur.',
          ),
          (
            'Données collectées',
            'Compte : adresse e-mail, nom d’affichage, identifiant de compte et métadonnées de confirmation des conditions et de majorité. Service d’apprentissage : collections, decks, cartes et contenus saisis ou importés, paramètres, échéances, réponses et journaux de révision. Support : adresse e-mail et contenu du message que vous envoyez. Les fournisseurs peuvent traiter des données techniques nécessaires à l’authentification, la sécurité et le fonctionnement (par exemple adresse IP, horodatage ou informations de requête); les journaux et leur durée sont à confirmer auprès de chaque fournisseur avant publication. Les contenus de cartes proviennent de ce que vous saisissez ou importez. Évitez d’y mettre des données sensibles ou concernant d’autres personnes.',
          ),
          (
            'Finalité et base légale',
            'La gestion du compte, la synchronisation, les fonctions pédagogiques et l’import/export reposent sur l’exécution du service demandé (article 6.1.b du RGPD). Les demandes de support et l’exercice des droits reposent sur l’intérêt légitime à gérer le service et les demandes, sous réserve de vos droits. Une obligation légale peut s’appliquer dans certains cas (article 6.1.c).',
          ),
          (
            'Hébergement et sous-traitant',
            'Supabase fournit l’authentification et la base de données synchronisée. L’hébergeur web, le fournisseur d’e-mails, la région du projet, les sous-traitants activés et les garanties de transfert doivent être vérifiés dans les paramètres et contrats avant publication. Aucune localisation ni garantie de transfert précise n’est affirmée sans cette vérification. Si un traitement ou transfert a lieu hors de l’Espace économique européen, les pays et garanties appropriées seront précisés ici après vérification.',
          ),
          (
            'Durée de conservation',
            'Les données du compte et d’apprentissage sont conservées jusqu’à la suppression du compte, sous réserve des obligations légales et des délais de sauvegarde des fournisseurs. Les préférences restent sur l’appareil jusqu’à leur effacement. Une réponse non synchronisée reste dans la file locale jusqu’à confirmation de son envoi ou effacement des données de l’application. Les durées des journaux techniques et des sauvegardes après suppression sont à confirmer. La suppression est demandée par e-mail et traitée manuellement; le bouton du profil prépare un e-mail et ne supprime pas directement le compte.',
          ),
          (
            'Vos droits',
            'Conformément au RGPD et à la législation belge, vous disposez des droits suivants :\n\n'
                '• Accès : obtenir une copie de vos données.\n'
                '• Rectification : corriger des données inexactes.\n'
                '• Suppression : demander l\'effacement de votre compte et de vos données.\n'
                '• Limitation et portabilité dans les cas prévus par le RGPD.\n'
                '• Opposition à un traitement fondé sur l’intérêt légitime.\n'
                'Les droits ne s’appliquent pas de la même manière à tous les traitements; tout refus ou toute restriction sera expliqué. Les demandes sont traitées dans le délai légal d’un mois, prolongeable de deux mois pour les demandes complexes avec information dans le premier mois. Pour une plainte : Autorité de protection des données, Rue de la Presse 35, 1000 Bruxelles, contact@apd-gba.be — https://www.autoriteprotectiondonnees.be/.',
          ),
          (
            'Décision automatisée',
            'Memflow calcule des échéances de révision à partir de vos réponses pour fournir la fonction de répétition espacée. Ce calcul n’a pas pour objet de prendre une décision produisant des effets juridiques ou vous affectant de manière significative au sens de l’article 22 du RGPD.',
          ),
          (
            'Sécurité et suppression',
            'Les données synchronisées sont protégées par les contrôles d’accès configurés pour les comptes et par les mesures des fournisseurs; aucune sécurité ne peut être garantie de manière absolue. Pour demander la suppression du compte, écrivez à contact@morganphemba.be. Le processus est manuel. Les copies techniques peuvent subsister temporairement selon les délais de sauvegarde des fournisseurs.',
          ),
          (
            'Ce que nous ne faisons pas',
            'Nous ne vendons pas vos données à des tiers.\n'
                'Nous n\'utilisons pas vos données à des fins publicitaires.\n'
                'Nous n\'intégrons aucun outil de tracking ou d\'analyse comportementale tiers.',
          ),
          (
            'Contact',
            'Pour toute question relative à vos données personnelles :\ncontact@morganphemba.be',
          ),
        ];

      case LegalDocument.terms:
        return const [
          (
            'Éditeur et service',
            'Memflow est un service gratuit de répétition espacée par cartes, proposé par Morgan Phemba, personne physique établie en Belgique. Il est disponible sur Android et sur le web et nécessite un compte pour synchroniser les contenus. Adresse postale de contact à compléter avant publication. Contact : contact@morganphemba.be.',
          ),
          (
            'Objet du service',
            'MemFlow est une application gratuite d\'apprentissage par flashcards utilisant la méthode de répétition espacée. Elle est disponible sur Android et sur le web.',
          ),
          (
            'Compte utilisateur',
            'Le service est réservé aux personnes âgées d’au moins 18 ans. Vous déclarez être majeur lors de l’inscription et confirmez de nouveau cette déclaration après cette mise à jour. Memflow ne vérifie pas votre identité. Vous fournissez une adresse e-mail valide et protégez vos identifiants. Les utilisateurs existants doivent confirmer leur majorité et accepter la version 2026-11-02 avant de retrouver leur espace.',
          ),
          (
            'Usage acceptable',
            'L\'application est destinée à un usage personnel d\'apprentissage.\n\n'
                'Il est interdit de :\n'
                '• utiliser le service à des fins illicites ;\n'
                '• tenter de porter atteinte à l\'intégrité ou à la disponibilité du service ;\n'
                '• accéder au compte ou aux données d’autrui.\n\n'
                'Vous restez responsable des contenus créés ou importés et devez disposer des droits nécessaires. Les contenus restent privés et ne sont pas publiés par Memflow. Pour signaler un contenu que vous estimez illicite ou contraire à ces conditions, écrivez à contact@morganphemba.be en indiquant son emplacement précis, les raisons du signalement et un moyen de vous répondre. Les signalements sont examinés par une personne; aucune modération automatisée n’est utilisée. Les contenus peuvent être restreints ou supprimés si la loi l’impose ou s’ils contreviennent aux conditions; les motifs et moyens de contestation sont communiqués lorsque la loi l’exige.',
          ),
          (
            'Disponibilité',
            'Le service est fourni « tel quel », sans garantie de disponibilité continue. MemFlow est en développement actif ; des interruptions ponctuelles peuvent survenir lors de mises à jour.',
          ),
          (
            'Responsabilité',
            'Les présentes conditions ne retirent aucun droit impératif dont vous bénéficiez en vertu du droit applicable. Dans les limites permises par la loi, Memflow ne garantit pas une disponibilité ininterrompue. Il est recommandé d’exporter les contenus importants.',
          ),
          (
            'Suppression de compte',
            'Vous pouvez demander la suppression du compte et des données associées par e-mail à contact@morganphemba.be. La demande est traitée manuellement; le bouton du profil prépare un e-mail et ne supprime pas les données directement.',
          ),
          (
            'Droit applicable',
            'Les présentes conditions sont régies par le droit belge, sans préjudice des protections impératives applicables dans votre pays de résidence. Elles ne limitent pas les droits que la loi accorde aux consommateurs.',
          ),
          (
            'Modifications',
            'La version actuelle est datée du 2 novembre 2026. Les changements importants seront soumis à votre acceptation avant de poursuivre l’utilisation du compte.',
          ),
        ];

      case LegalDocument.notices:
        return const [
          (
            'Éditeur',
            'Morgan Phemba — personne physique établie en Belgique. Courriel : contact@morganphemba.be. Adresse postale de contact à compléter avant publication. Si l’activité relève d’une entreprise ou d’une activité professionnelle, les mentions belges applicables (adresse d’établissement, numéro BCE et coordonnées requises) devront être ajoutées.',
          ),
          (
            'Hébergement des données',
            'Supabase fournit l’authentification et la base de données. L’hébergeur web, les coordonnées légales des prestataires et la région d’hébergement effective sont à renseigner après vérification des contrats et paramètres avant publication.',
          ),
          (
            'Propriété intellectuelle',
            'L\'application MemFlow, son nom, son logo et l\'ensemble de ses contenus sont la propriété de Morgan Phemba.\n\n'
                'Les dépendances open-source utilisées dans l\'application sont soumises à leurs licences respectives, consultables depuis la section « Licences open-source » de cette page.',
          ),
          (
            'Contact',
            'Pour toute question : contact@morganphemba.be. Adresse postale de contact et informations exactes sur les prestataires à compléter avant publication.',
          ),
          (
            'Signalement de contenu illicite',
            'Un mécanisme électronique de signalement est disponible par e-mail à contact@morganphemba.be. Indiquez l’emplacement précis du contenu, expliquez pourquoi vous le considérez illicite et laissez un moyen de réponse. Les contenus ne sont pas diffusés publiquement.',
          ),
        ];
      case LegalDocument.cookies:
        return const [
          (
            'Cookies web',
            'Le navigateur utilise les cookies de session nécessaires à Supabase Auth pour maintenir votre connexion. Leur durée dépend de la session configurée. Aucun cookie publicitaire ou outil d’analyse tiers n’est intégré dans le code actuel. Une bannière n’est pas présentée pour ces seuls stockages nécessaires.',
          ),
          (
            'Stockage local web',
            'Le stockage local conserve vos préférences de révision sur cet appareil. IndexedDB conserve les réponses non synchronisées jusqu’à confirmation de leur envoi. Vous pouvez effacer ces stockages dans les paramètres du navigateur; les données déjà synchronisées ne sont pas supprimées.',
          ),
          (
            'Android',
            'Android stocke localement les données nécessaires au fonctionnement hors ligne dans sa base chiffrée et conserve les préférences de l’appareil. Aucun service Sentry de rapport d’erreurs à distance n’est initialisé. Ces stockages applicatifs ne sont pas des cookies.',
          ),
          (
            'Évolution des traceurs',
            'Si des outils de mesure d’audience, de publicité ou d’autres traceurs non strictement nécessaires sont ajoutés, ils resteront désactivés jusqu’à un consentement préalable, libre, éclairé et retirable. La notice et les contrôles de consentement devront alors être mis à jour.',
          ),
          (
            'Suppression',
            'Effacer le navigateur ou les données de l’application retire les copies locales, mais ne supprime pas nécessairement les données du compte. Pour demander leur suppression, écrivez à contact@morganphemba.be.',
          ),
        ];
    }
  }
}

/// Shared by the profile screen and any future entry point: opens the native
/// Flutter licenses page with MemFlow branding.
void showMemFlowLicensePage(BuildContext context) {
  showLicensePage(
    context: context,
    applicationName: 'MemFlow',
    applicationVersion: appVersion,
    applicationIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'memflow.png',
          width: 56,
          height: 56,
          cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context)).round(),
        ),
      ),
    ),
  );
}
