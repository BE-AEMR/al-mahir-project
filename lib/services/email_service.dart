import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/team_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  // Clé API Brevo
  static String get apiKey => dotenv.env['SENDINBLUE_API_KEY'] ?? '';
  static const String apiUrl = 'https://api.brevo.com/v3/smtp/email';

  // Méthode pour envoyer un email simple
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
    String senderName = 'AL MAHIR Project',
    String senderEmail = 'echiyahya@live.fr',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'accept': 'application/json',
          'api-key': apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {
            'name': senderName,
            'email': senderEmail,
          },
          'to': [
            {
              'email': to,
            }
          ],
          'subject': subject,
          'htmlContent': htmlContent,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('Email envoyé avec succès à $to');
        return true;
      } else {
        print('Erreur lors de l\'envoi de l\'email: ${response.statusCode}');
        print('Réponse: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception lors de l\'envoi de l\'email: $e');
      return false;
    }
  }

  // Méthode pour envoyer un email d'invitation
  static Future<bool> sendInvitationEmail({
    required String to,
    required String teamName,
    required String inviterName,
    required String token,
    required String teamId,
  }) async {
    // Générer l'URL d'invitation pour application mobile
    final invitationUrl = 'webxio://invitation?token=$token&team=$teamId';

    // Créer le contenu HTML en utilisant le nouveau template
    final htmlContent = '''
    <!DOCTYPE html>
    <html lang="fr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Invitation à rejoindre $teamName sur AL MAHIR Project</title>
      <style>
        body {
          margin: 0;
          padding: 0;
          background: linear-gradient(to bottom, #1F4E5F, #0D2B36);
          font-family: Arial, sans-serif;
          color: #ffffff;
        }
        .email-container {
          max-width: 600px;
          margin: 50px auto;
          background-color: rgba(0, 0, 0, 0.3);
          border-radius: 8px;
          overflow: hidden;
          position: relative;
          padding: 20px;
          text-align: center;
        }
        .email-container::before {
          content: "";
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          background-size: cover;
          opacity: 0.09;
          z-index: 0;
        }
        .content {
          position: relative;
          z-index: 1;
        }
        h2 {
          color: #FFD900;
          margin-bottom: 20px;
        }
        p {
          line-height: 1.5;
          margin: 0 0 20px;
        }
        .btn {
          display: inline-block;
          background-color: #FFD900;
          color: #0D2B36;
          padding: 12px 24px;
          text-decoration: none;
          border-radius: 5px;
          font-weight: bold;
          margin: 20px 0;
        }
        .footer {
          font-size: 12px;
          color: #cccccc;
          margin-top: 20px;
        }
        .details {
          background-color: rgba(255, 255, 255, 0.1);
          padding: 15px;
          border-radius: 5px;
          margin: 20px 0;
          text-align: left;
        }
        .code {
          background-color: rgba(0, 0, 0, 0.3);
          padding: 10px;
          border-radius: 4px;
          font-family: monospace;
          letter-spacing: 1px;
          margin: 10px 0;
        }
      </style>
    </head>
    <body>
      <div class="email-container">
        <div class="content">
          <h2>Invitation à rejoindre l'équipe $teamName</h2>
          <p>$inviterName vous a invité à rejoindre leur équipe sur l'application AL MAHIR Project Gestion des Projets.</p>
          <a class="btn" href="$invitationUrl">Accepter l'invitation</a>
          <div class="details">
            <p>Si le bouton ne fonctionne pas, vous pouvez utiliser ces informations dans l'application :</p>
            <p><strong>Code d'invitation:</strong> <span class="code">$token</span></p>
            <p><strong>ID d'équipe:</strong> <span class="code">$teamId</span></p>
          </div>
          <p class="footer">Ce lien expirera dans 7 jours. Si vous n'avez pas demandé cette invitation, veuillez ignorer cet email.</p>
        </div>
      </div>
    </body>
    </html>
    ''';

    // Sujet de l'email
    final subject = 'Invitation à rejoindre l\'équipe $teamName';

    // Envoyer l'email
    return sendEmail(
      to: to,
      subject: subject,
      htmlContent: htmlContent,
    );
  }

  // Méthode pour envoyer un email d'invitation à partir d'un objet Invitation
  static Future<bool> sendInvitationEmailFromInvitation(Invitation invitation) async {
    try {
      final senderEmail = 'echiyahya@live.fr';
      final senderName = 'AL MAHIR Project';

      // Générer le lien avec un schéma personnalisé pour les appareils mobiles
      final invitationLink = 'webxio://invitation?token=${invitation.token}&team=${invitation.teamId}';

      // Contenu HTML de l'email avec le nouveau template
      final htmlContent = '''
      <!DOCTYPE html>
      <html lang="fr">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Invitation à rejoindre ${invitation.teamName} sur AL MAHIR Project</title>
        <style>
          body {
            margin: 0;
            padding: 0;
            background: linear-gradient(to bottom, #1F4E5F, #0D2B36);
            font-family: Arial, sans-serif;
            color: #ffffff;
          }
          .email-container {
            max-width: 600px;
            margin: 50px auto;
            background-color: rgba(0, 0, 0, 0.3);
            border-radius: 8px;
            overflow: hidden;
            position: relative;
            padding: 20px;
            text-align: center;
          }
          .email-container::before {
            content: "";
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-size: cover;
            opacity: 0.09;
            z-index: 0;
          }
          .content {
            position: relative;
            z-index: 1;
          }
          h2 {
            color: #FFD900;
            margin-bottom: 20px;
          }
          p {
            line-height: 1.5;
            margin: 0 0 20px;
          }
          .btn {
            display: inline-block;
            background-color: #FFD900;
            color: #0D2B36;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
            margin: 20px 0;
          }
          .footer {
            font-size: 12px;
            color: #cccccc;
            margin-top: 20px;
          }
          .details {
            background-color: rgba(255, 255, 255, 0.1);
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            text-align: left;
          }
          .code {
            background-color: rgba(0, 0, 0, 0.3);
            padding: 10px;
            border-radius: 4px;
            font-family: monospace;
            letter-spacing: 1px;
            margin: 10px 0;
          }
          ul {
            text-align: left;
            padding-left: 20px;
          }
        </style>
      </head>
      <body>
        <div class="email-container">
          <div class="content">
            <h2>Invitation à rejoindre une équipe sur AL MAHIR Project</h2>
            <p>Bonjour,</p>
            <p>Vous avez été invité(e) à rejoindre l'équipe <strong>${invitation.teamName ?? 'sur AL MAHIR Project'}</strong>.</p>
            
            <a class="btn" href="$invitationLink">Accepter l'invitation</a>
            
            <div class="details">
              <p><strong>Si le bouton ne fonctionne pas :</strong></p>
              <p>Ouvrez l'application AL MAHIR Project et saisissez le code d'invitation :</p>
              <div class="code">
                <strong>${invitation.token}</strong>
              </div>
              
              <p><strong>Informations supplémentaires :</strong></p>
              <ul>
                <li>Token: ${invitation.token}</li>
                <li>ID de l'équipe: ${invitation.teamId}</li>
                <li>Cette invitation expirera le ${DateFormat('yyyy-MM-dd à HH:mm').format(invitation.expiresAt ?? DateTime.now().add(const Duration(days: 7)))}</li>
              </ul>
            </div>
            
            <p class="footer">Ce message a été envoyé automatiquement par AL MAHIR Project. Merci de ne pas y répondre.</p>
          </div>
        </div>
      </body>
      </html>
      ''';

      // Texte brut de l'email (pour les clients qui ne prennent pas en charge le HTML)
      final textContent = '''
      Invitation à rejoindre une équipe sur AL MAHIR Project
      
      Bonjour,
      
      Vous avez été invité(e) à rejoindre l'équipe ${invitation.teamName ?? 'sur AL MAHIR Project'}.
      
      Pour accepter l'invitation, veuillez cliquer sur ce lien ou le copier dans votre navigateur :
      $invitationLink
      
      Si le lien ne fonctionne pas, vous pouvez également ouvrir l'application AL MAHIR Project et saisir manuellement le code d'invitation suivant :
      ${invitation.token}
      
      Informations supplémentaires :
      - Token: ${invitation.token}
      - ID de l'équipe: ${invitation.teamId}
      - Cette invitation expirera le ${DateFormat('yyyy-MM-dd à HH:mm').format(invitation.expiresAt ?? DateTime.now().add(const Duration(days: 7)))}
      
      Ce message a été envoyé automatiquement par AL MAHIR Project. Merci de ne pas y répondre.
      ''';

      // Envoyer l'email
      return sendEmail(
        to: invitation.email,
        subject: 'Invitation à rejoindre l\'équipe ${invitation.teamName}',
        htmlContent: htmlContent,
      );
    } catch (e) {
      print('Exception lors de l\'envoi de l\'email: $e');
      return false;
    }
  }
}
