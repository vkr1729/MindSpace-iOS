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
    direct_ipa_url = "https://github.com/vkr1729/mindspace-source/releases/download/v2.4.0/MindSpace.ipa"
    github_release_url = "https://github.com/vkr1729/mindspace-source/releases/tag/v2.4.0"
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "MindSpace iOS v2.4.0 Released — AI Celestial Artworks, GitHub Streaming & Singles Downloads"
    msg["From"] = f"MindSpace AI Assistant <{sender_email}>"
    msg["To"] = recipient_email
    
    text_content = f"""Hi Kedar,

MindSpace iOS v2.4.0 (Build 11) is officially live and ready for SideStore refresh!

=== WHAT'S NEW IN V2.4.0 ===
• Photorealistic AI Celestial Artworks: Fresh 3D planet artworks with 100% native RGBA alpha transparency (zero square boundaries across all screens).
• Serene Photorealistic App Icon: High-detail celestial sphere render tailored to the iOS squircle with radiant atmospheric rim lighting.
• On-Demand Private GitHub Streaming: Stream any un-downloaded track seamlessly using authenticated AVURLAsset with Keychain PAT.
• Category-Level Singles Downloads: 1-tap download buttons for all Singles categories (Sleep Sounds, SOS, Classics, etc.) with live progress.
• Zero-Drift Version Pipeline: Single Source of Truth architecture guaranteeing zero version mismatch errors in SideStore.

=== HOW TO REFRESH IN SIDESTORE ===
1. Open SideStore on your iPhone.
2. Ensure your Source URL is:
   {source_url}
3. Pull to refresh the Sources tab, and tap "Update" on MindSpace v2.4.0.
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
            <h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px;">MindSpace iOS v2.4.0</h1>
            <p style="color: #ddd6fe; margin: 8px 0 0 0; font-size: 14px; font-weight: 500;">AI Celestial Artworks • GitHub Streaming • Singles Downloads</p>
          </div>
          
          <div style="padding: 28px 24px; color: #f1f5f9;">
            <p style="font-size: 15px; line-height: 1.6; margin-top: 0;">Hi Kedar,</p>
            <p style="font-size: 15px; line-height: 1.6; color: #cbd5e1;">MindSpace iOS <strong>v2.4.0 (Build 11)</strong> has been compiled, verified, and released with photorealistic AI celestial artworks, authenticated private GitHub streaming fallback, and Singles category downloads.</p>
            
            <!-- Features Card -->
            <div style="background: #1a1e38; border-left: 4px solid #7c3aed; padding: 18px; border-radius: 12px; margin: 22px 0;">
              <h4 style="margin: 0 0 10px 0; color: #c4b5fd; font-size: 15px;">✨ What Was Upgraded in v2.4.0:</h4>
              <ul style="margin: 0; padding-left: 18px; font-size: 13px; color: #e2e8f0; line-height: 1.7;">
                <li><strong>Photorealistic AI Celestial Artworks:</strong> Rendered all 9 celestial planet bodies with 100% native RGBA alpha transparency. Zero square layout artifacts across all views.</li>
                <li><strong>Serene Photorealistic App Icon:</strong> Rendered non-cartoonish deep cosmic sphere with crystalline rings and limb backlighting.</li>
                <li><strong>On-Demand GitHub Streaming:</strong> Intelligent AVURLAsset fallback allows streaming un-downloaded tracks directly from your private repository.</li>
                <li><strong>Singles Category Downloads:</strong> 1-tap download buttons for all Singles categories with live progress indicators.</li>
                <li><strong>Zero-Drift Version Engine:</strong> Single Source of Truth pipeline eliminating SideStore version mismatch errors permanently.</li>
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
              <a href="{direct_ipa_url}" style="background: linear-gradient(135deg, #7c3aed, #6d28d9); color: #ffffff; padding: 15px 32px; text-decoration: none; border-radius: 12px; font-weight: 700; font-size: 15px; display: inline-block; box-shadow: 0 6px 20px rgba(124, 58, 237, 0.45);">Download MindSpace.ipa v2.4.0</a>
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
