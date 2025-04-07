// Supabase Edge Function pour envoyer un email d'invitation
import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.42.0"

interface Invitation {
  id: string
  email: string
  team_id: string
  invited_by: string
  team_name: string
  token: string
}

serve(async (req) => {
  try {
    // Créer un client Supabase avec les clés d'API du service
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

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

    // Récupérer les données de l'invitation depuis le corps de la requête
    const invitation: Invitation = await req.json();

    // Valider les données requises
    if (!invitation.email || !invitation.team_name || !invitation.token) {
      return new Response(JSON.stringify({ error: "Données d'invitation incomplètes" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Récupérer les informations de l'invitant
    const { data: inviterData, error: inviterError } = await supabase
      .from("profiles")
      .select("display_name, email")
      .eq("id", invitation.invited_by)
      .single();

    if (inviterError) {
      console.error("Erreur lors de la récupération de l'invitant:", inviterError);
    }

    const inviterName = inviterData?.display_name || inviterData?.email || "Un membre";

    // Générer l'URL d'invitation
    const appUrl = Deno.env.get("APP_URL") || "http://localhost:3000";
    const invitationUrl = `${appUrl}/invitation?token=${invitation.token}&team=${invitation.team_id}`;

    // Configurer l'email
    const emailSubject = `Invitation à rejoindre l'équipe ${invitation.team_name}`;
    const emailContent = `
    <h2>Vous avez été invité à rejoindre l'équipe ${invitation.team_name}</h2>
    <p>${inviterName} vous a invité à rejoindre leur équipe sur l'application WebXIO.</p>
    <p>Pour accepter cette invitation, veuillez cliquer sur le lien ci-dessous :</p>
    <p><a href="${invitationUrl}">Accepter l'invitation</a></p>
    <p>Ce lien expirera dans 7 jours.</p>
    <p>Si vous n'avez pas demandé cette invitation, vous pouvez ignorer cet email.</p>
    `;

    // Envoyer l'email via l'API Supabase
    const { error: emailError } = await supabase.functions.invoke("send-email", {
      body: {
        to: invitation.email,
        subject: emailSubject,
        html: emailContent,
      },
    });

    if (emailError) {
      console.error("Erreur lors de l'envoi de l'email:", emailError);
      return new Response(JSON.stringify({ error: "Erreur lors de l'envoi de l'email" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ 
      success: true, 
      message: `Email d'invitation envoyé à ${invitation.email}` 
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Erreur inattendue:", error);
    return new Response(JSON.stringify({ error: "Erreur du serveur" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
})
