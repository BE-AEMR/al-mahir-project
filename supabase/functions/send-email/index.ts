// Supabase Edge Function pour envoyer des emails
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { SmtpClient } from "https://deno.land/x/smtp@v0.7.0/mod.ts";

interface EmailPayload {
  to: string;
  subject: string;
  html: string;
  from?: string;
}

serve(async (req) => {
  try {
    // Vérifier si la requête est autorisée
    const authHeader = req.headers.get("Authorization");
    // Désactiver temporairement la vérification d'auth pour le déboggage
    /* 
    if (!authHeader || !authHeader.startsWith("Bearer ") || authHeader.split(" ")[1] !== Deno.env.get("FUNCTION_SECRET")) {
      return new Response(JSON.stringify({ error: "Non autorisé" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
    */

    // Récupérer les données de l'email depuis le corps de la requête
    const payload: EmailPayload = await req.json();

    // Valider les données requises
    if (!payload.to || !payload.subject || !payload.html) {
      return new Response(JSON.stringify({ error: "Données d'email incomplètes" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Configurer le client SMTP
    const client = new SmtpClient();
    const smtpConfig = {
      hostname: Deno.env.get("SMTP_HOST") || "",
      port: parseInt(Deno.env.get("SMTP_PORT") || "587"),
      username: Deno.env.get("SMTP_USERNAME") || "",
      password: Deno.env.get("SMTP_PASSWORD") || "",
    };

    // Se connecter au serveur SMTP
    await client.connectTLS(smtpConfig);

    // Envoyer l'email
    await client.send({
      from: payload.from || Deno.env.get("EMAIL_FROM") || "noreply@webxio.app",
      to: payload.to,
      subject: payload.subject,
      content: payload.html,
      html: payload.html,
    });

    // Fermer la connexion
    await client.close();

    return new Response(JSON.stringify({ 
      success: true, 
      message: `Email envoyé à ${payload.to}` 
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Erreur lors de l'envoi de l'email:", error);
    return new Response(JSON.stringify({ error: "Erreur du serveur: " + error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
