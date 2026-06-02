import 'package:flutter/material.dart';

/// The legal documents shown from the profile screen. Bodies are placeholders
/// to be replaced with the final, reviewed legal text.
enum LegalDocument {
  privacy,
  terms,
  notices;

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
      };

  String get title => switch (this) {
        LegalDocument.privacy => 'Politique de confidentialité',
        LegalDocument.terms => "Conditions d'utilisation",
        LegalDocument.notices => 'Mentions légales',
      };
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(
                  'Dernière mise à jour : 30 mai 2026',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 16),
                ..._sectionsFor(document).map(
                  (section) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.$1, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          section.$2,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
            'Responsable du traitement',
            'Morgan Phemba, particulier — Belgique\nmorgan.phemba@gmail.com',
          ),
          (
            'Données collectées',
            'Lors de la création d\'un compte, nous collectons votre adresse email et un identifiant utilisateur unique (UUID) généré automatiquement.\n\n'
                'Les données pédagogiques que vous créez dans l\'application (collections, decks, flashcards, historique de révision) sont également stockées pour assurer la synchronisation entre vos appareils.',
          ),
          (
            'Finalité et base légale',
            'Vos données sont traitées exclusivement pour vous permettre de synchroniser et sauvegarder vos données d\'apprentissage sur plusieurs appareils.\n\n'
                'Base légale : exécution du contrat d\'utilisation (article 6.1.b du RGPD).',
          ),
          (
            'Hébergement et sous-traitant',
            'Les données sont hébergées par Supabase Inc. (970 Trestle Glen Rd, Oakland CA 94610, États-Unis), agissant en qualité de sous-traitant.\n\n'
                'Le transfert vers les États-Unis est encadré par les clauses contractuelles types approuvées par la Commission européenne, conformément au RGPD.',
          ),
          (
            'Durée de conservation',
            'Vos données sont conservées jusqu\'à la suppression de votre compte.\n\n'
                'La suppression automatique du compte depuis l\'application est en cours d\'implémentation. En attendant, vous pouvez en faire la demande à tout moment depuis la page Profil — la demande sera traitée sous 30 jours.',
          ),
          (
            'Vos droits',
            'Conformément au RGPD et à la législation belge, vous disposez des droits suivants :\n\n'
                '• Accès : obtenir une copie de vos données.\n'
                '• Rectification : corriger des données inexactes.\n'
                '• Suppression : demander l\'effacement de votre compte et de vos données.\n'
                '• Portabilité : exporter vos flashcards au format CSV depuis la page Profil.\n'
                '• Réclamation : introduire une plainte auprès de l\'Autorité de protection des données (APD) belge — www.autoriteprotectiondonnees.be.',
          ),
          (
            'Ce que nous ne faisons pas',
            'Nous ne vendons pas vos données à des tiers.\n'
                'Nous n\'utilisons pas vos données à des fins publicitaires.\n'
                'Nous n\'intégrons aucun outil de tracking ou d\'analyse comportementale tiers.',
          ),
          (
            'Contact',
            'Pour toute question relative à vos données personnelles :\nmorgan.phemba@gmail.com',
          ),
        ];

      case LegalDocument.terms:
        return const [
          (
            'Objet du service',
            'MemFlow est une application gratuite d\'apprentissage par flashcards utilisant la méthode de répétition espacée. Elle est disponible sur Android et sur le web.',
          ),
          (
            'Compte utilisateur',
            'Un compte est requis pour utiliser la fonctionnalité de synchronisation multi-appareils. Vous êtes responsable de la confidentialité de vos identifiants de connexion.\n\n'
                'Vous vous engagez à fournir une adresse email valide lors de la création de votre compte.',
          ),
          (
            'Usage acceptable',
            'L\'application est destinée à un usage personnel d\'apprentissage.\n\n'
                'Il est interdit de :\n'
                '• utiliser le service à des fins illicites ;\n'
                '• tenter de porter atteinte à l\'intégrité ou à la disponibilité du service ;\n'
                '• usurper l\'identité d\'un autre utilisateur.',
          ),
          (
            'Disponibilité',
            'Le service est fourni « tel quel », sans garantie de disponibilité continue. MemFlow est en développement actif ; des interruptions ponctuelles peuvent survenir lors de mises à jour.',
          ),
          (
            'Responsabilité',
            'Morgan Phemba ne peut être tenu responsable de pertes de données résultant d\'un cas de force majeure, d\'une défaillance du sous-traitant hébergeur, ou d\'une utilisation incorrecte de l\'application.\n\n'
                'Il est recommandé d\'exporter régulièrement vos données via la fonction « Exporter en CSV » disponible dans la page Profil.',
          ),
          (
            'Suppression de compte',
            'Vous pouvez demander la suppression de votre compte à tout moment depuis la page Profil. La demande sera traitée sous 30 jours.\n\n'
                'La suppression automatique directement depuis l\'application est en cours d\'implémentation.',
          ),
          (
            'Droit applicable',
            'Les présentes conditions sont régies par le droit belge. En cas de litige, les tribunaux compétents sont ceux de Belgique.',
          ),
          (
            'Modifications',
            'Ces conditions peuvent évoluer. En cas de changement substantiel, vous serez informé via l\'application. La poursuite de l\'utilisation du service après notification vaut acceptation des nouvelles conditions.',
          ),
        ];

      case LegalDocument.notices:
        return const [
          (
            'Éditeur',
            'Morgan Phemba\nParticulier — Belgique\nmorgan.phemba@gmail.com',
          ),
          (
            'Hébergement des données',
            'Supabase Inc.\n970 Trestle Glen Rd\nOakland, CA 94610 — États-Unis\nhttps://supabase.com',
          ),
          (
            'Propriété intellectuelle',
            'L\'application MemFlow, son nom, son logo et l\'ensemble de ses contenus sont la propriété de Morgan Phemba.\n\n'
                'Les dépendances open-source utilisées dans l\'application sont soumises à leurs licences respectives, consultables depuis la section « Licences open-source » de cette page.',
          ),
          (
            'Contact',
            'Pour toute question ou réclamation :\nmorgan.phemba@gmail.com',
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
    applicationVersion: '1.5.0',
    applicationIcon: Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset('memflow.png', width: 56, height: 56),
      ),
    ),
  );
}
