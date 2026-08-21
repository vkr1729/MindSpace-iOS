import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def parse_env(file_path):
    env_vars = {}
    with open(file_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                k, v = line.split("=", 1)
                k = k.strip()
                v = v.strip().strip("'\"")
                env_vars[k] = v
    return env_vars

def send_credentials_and_release_email():
    env_path = "/home/kedarnath-reddy-vallaboina/.env"
    config = parse_env(env_path)
    
    smtp_server = config.get("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(config.get("SMTP_PORT", "587"))
    smtp_user = config.get("SMTP_USERNAME")
    smtp_pass = config.get("SMTP_PASSWORD")
    sender_email = config.get("SENDER_EMAIL", smtp_user)
    recipient_email = config.get("RECIPIENT_EMAIL", smtp_user)
    
    github_pat = config.get("GITHUB_PAT", "")
    content_repo = "vkr1729/MindSpace-Content"
    content_repo_url = f"https://github.com/{content_repo}"
    
    source_url = "https://vkr1729.github.io/mindspace-source/apps.json"
    direct_ipa_url = "https://github.com/vkr1729/mindspace-source/releases/download/v2.3.0/MindSpace.ipa"
    github_release_url = "https://github.com/vkr1729/mindspace-source/releases/tag/v2.3.0"
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "MindSpace iOS v2.3.0 Released — Cinematic Celestial Visuals, App Icon & SideStore Refresh"
    msg["From"] = f"MindSpace AI Assistant <{sender_email}>"
    msg["To"] = recipient_email
    
    text_content = f"""Hi Kedar,

MindSpace iOS v2.3.0 (Build 10) is officially live and ready for SideStore refresh!

=== WHAT'S NEW IN V2.3.0 ===
• Cinematic Hybrid Celestial Visuals: Converted all 9 planet artworks to 100% transparent alpha with sub-pixel feathering. Zero square box boundaries across all screens (Player, Library, Progress, Today, Completion, and Onboarding).
• Atmospheric Coronas & Specular Rims: Layered radial glow tuned to course ambient hues (Moon Lavender, Aurora Teal, Solar Coral, Cosmic Purple) with delicate specular light curves.
• Mindful Breathing Respiration: Synchronized 4.0-second visual breathing anchor during meditation playback with automatic accessibility Reduce Motion support.
• Polished iOS App Icon: Refined with deep cosmic space gradients, radiant nebula backlighting, and a high-contrast celestial focal body.
• Private GitHub Content Sync: Keychain-stored PAT credentials and on-demand selective downloads.

=== HOW TO REFRESH IN SIDESTORE ===
1. Open SideStore on your iPhone.
2. Ensure your Source URL is:
   {source_url}
3. Pull to refresh the Sources tab, or tap "Update" on MindSpace to install v2.3.0.
4. Direct IPA Download: {direct_ipa_url}

=== PRIVATE GITHUB CONTENT REPOSITORY ===
• Repository: {content_repo_url}
• Personal Access Token (PAT): {github_pat}

Best regards,
MindSpace AI Assistant
"""

    html_content = f"""
    <html>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; background-color: #0b0d17; padding: 24px;">
        <div style="max-width: 640px; margin: 0 auto; background: #121528; border-radius: 20px; border: 1px solid rgba(124, 58, 237, 0.3); overflow: hidden; box-shadow: 0 16px 40px rgba(0,0,0,0.6);">
          <div style="background: linear-gradient(135deg, #4c1d95, #6d28d9, #7c3aed); padding: 36px 24px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px;">MindSpace iOS v2.3.0</h1>
            <p style="color: #ddd6fe; margin: 8px 0 0 0; font-size: 14px; font-weight: 500;">Cinematic Celestial Visuals • Polished App Icon • SideStore Refresh</p>
          </div>
          
          <div style="padding: 28px 24px; color: #f1f5f9;">
            <p style="font-size: 15px; line-height: 1.6; margin-top: 0;">Hi Kedar,</p>
            <p style="font-size: 15px; line-height: 1.6; color: #cbd5e1;">MindSpace iOS <strong>v2.3.0 (Build 10)</strong> has been compiled, verified, and released with the new <strong>Cinematic Hybrid</strong> celestial visual architecture and polished App Icon.</p>
            
            <!-- Features Card -->
            <div style="background: #1a1e38; border-left: 4px solid #7c3aed; padding: 18px; border-radius: 12px; margin: 22px 0;">
              <h4 style="margin: 0 0 10px 0; color: #c4b5fd; font-size: 15px;">✨ What Was Upgraded in v2.3.0:</h4>
              <ul style="margin: 0; padding-left: 18px; font-size: 13px; color: #e2e8f0; line-height: 1.7;">
                <li><strong>Cinematic Hybrid Celestial Bodies:</strong> 100% transparent alpha blending on all 9 planet artworks. Completely eliminates square box boundaries across Player, Library, Progress, and Celebration views.</li>
                <li><strong>Atmospheric Coronas & Specular Rims:</strong> Multi-stop radial backlighting matching category hues with delicate specular rim lighting.</li>
                <li><strong>Mindful Breathing Physics:</strong> Hypnotic 4-second synchronized visual respiration guide during playback.</li>
                <li><strong>Polished iOS App Icon:</strong> Deep space cosmic gradients, radiant nebula backlighting, and high-contrast celestial focus.</li>
                <li><strong>Private GitHub Content Sync:</strong> Secure Keychain-stored PAT credentials and on-demand selective downloads.</li>
              </ul>
            </div>

            <!-- Credentials Card -->
            <div style="background: #1a1e38; border-left: 4px solid #10b981; padding: 18px; border-radius: 12px; margin: 22px 0;">
              <h4 style="margin: 0 0 10px 0; color: #6ee7b7; font-size: 15px;">🔒 Private Content Repository Details:</h4>
              <p style="margin: 6px 0; font-size: 13px; color: #cbd5e1;"><strong>Repository:</strong> <a href="{content_repo_url}" style="color: #a78bfa; font-family: monospace; font-weight: bold;">{content_repo}</a></p>
              <p style="margin: 6px 0; font-size: 13px; color: #cbd5e1;"><strong>Personal Access Token (PAT):</strong></p>
              <div style="background: #0d1020; padding: 10px 14px; border-radius: 8px; font-family: monospace; font-size: 13px; color: #facc15; word-break: break-all; margin-top: 4px; border: 1px solid rgba(255,255,255,0.1);">
                {github_pat}
              </div>
            </div>

            <!-- SideStore Source Box -->
            <div style="background: #181b33; border: 1px solid rgba(255,255,255,0.08); padding: 16px; border-radius: 12px; margin: 24px 0;">
              <h3 style="margin: 0 0 6px 0; font-size: 12px; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.5px;">SideStore / AltStore Community Source URL</h3>
              <code style="font-family: monospace; font-size: 13px; color: #a78bfa; word-break: break-all; font-weight: 600;">{source_url}</code>
            </div>

            <div style="text-align: center; margin: 28px 0;">
              <a href="{direct_ipa_url}" style="background: linear-gradient(135deg, #7c3aed, #6d28d9); color: #ffffff; padding: 15px 32px; text-decoration: none; border-radius: 12px; font-weight: 700; font-size: 15px; display: inline-block; box-shadow: 0 6px 20px rgba(124, 58, 237, 0.45);">Download MindSpace.ipa v2.3.0</a>
            </div>
          </div>
          
          <div style="background: #0d1020; border-top: 1px solid rgba(255,255,255,0.06); padding: 16px 24px; text-align: center; font-size: 12px; color: #64748b;">
            MindSpace iOS • 100% Offline & Private Celestial Meditation
          </div>
        </div>
      </body>
    </html>
    """
    
    msg.attach(MIMEText(text_content, "plain"))
    msg.attach(MIMEText(html_content, "html"))
    
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)
        print("Email sent successfully to", recipient_email)

if __name__ == "__main__":
    send_credentials_and_release_email()
