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

def send_update_email():
    env_path = "/home/kedarnath-reddy-vallaboina/.env"
    config = parse_env(env_path)
    
    smtp_server = config.get("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(config.get("SMTP_PORT", "587"))
    smtp_user = config.get("SMTP_USERNAME")
    smtp_pass = config.get("SMTP_PASSWORD")
    sender_email = config.get("SENDER_EMAIL", smtp_user)
    recipient_email = config.get("RECIPIENT_EMAIL", smtp_user)
    
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "MindSpace iOS — SideStore Community Source & Auto-Update Ready"
    msg["From"] = f"MindSpace AI Assistant <{sender_email}>"
    msg["To"] = recipient_email
    
    source_url = "https://raw.githubusercontent.com/vkr1729/MindSpace-iOS/main/dist/apps.json"
    source_url_alt = "https://raw.githubusercontent.com/vkr1729/MindSpace-iOS/main/apps.json"
    direct_ipa_url = "https://github.com/vkr1729/MindSpace-iOS/releases/download/latest/MindSpace.ipa"
    repo_url = "https://github.com/vkr1729/MindSpace-iOS"
    
    text_content = f"""Hi Kedar,

The SideStore / AltStore JSON source and GitHub Actions CI build have been completely validated and fixed!

SideStore / AltStore Community Source Link:
{source_url}

Alternative Link:
{source_url_alt}

Direct IPA Download Link:
{direct_ipa_url}

GitHub Repository:
{repo_url}

How to Auto-Update via SideStore:
1. Open SideStore on your iPhone.
2. Go to the "Sources" tab.
3. Tap "+" in the top corner.
4. Paste the Source URL:
   {source_url}
5. MindSpace will appear under your Sources list. SideStore will detect version 1.0.1 (Build 2) and allow one-tap updating and future seamless automatic updates directly over Wi-Fi!

What's New in MindSpace v1.0.1:
- Full-Screen Video Mode: Native edge-to-edge playback for course videos.
- Photorealistic Celestial Planet Visuals: 9 cinematic celestial artworks for Foundation, Health, Happiness, Work, Sleep, Brave, Students, Pro, and Sport.
- Daily Dynamic Recommendations: Today's journey accurately picks the next uncompleted session from your active course.
- Daily Sleep Sounds: Rotating sleep sound card with duration options.
- 5-Min Reset & SOS Navigation: Correct separation between Unwind Reset and SOS panic relief.
- Privacy-First Progress & Data Portability: Active course filtering, streak protection with Compassion Passes, and .mindspace offline backup import/export.

Best regards,
MindSpace Assistant
"""

    html_content = f"""
    <html>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; background-color: #f8fafc; padding: 24px;">
        <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1);">
          <div style="background: linear-gradient(135deg, #4f46e5, #7c3aed); padding: 28px 24px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700;">MindSpace iOS</h1>
            <p style="color: #e0e7ff; margin: 8px 0 0 0; font-size: 14px;">SideStore Community Source & Auto-Update Ready</p>
          </div>
          
          <div style="padding: 24px;">
            <p style="font-size: 15px; line-height: 1.6; margin-top: 0;">Hi Kedar,</p>
            <p style="font-size: 15px; line-height: 1.6;">The SideStore / AltStore JSON schema has been strictly validated and the automated build and release pipeline is fully functional.</p>
            
            <div style="background: #f1f5f9; border-left: 4px solid #7c3aed; padding: 16px; border-radius: 6px; margin: 20px 0;">
              <h3 style="margin: 0 0 8px 0; font-size: 14px; text-transform: uppercase; color: #64748b; letter-spacing: 0.5px;">SideStore / AltStore Source URL</h3>
              <code style="font-family: monospace; font-size: 13px; color: #6d28d9; word-break: break-all; font-weight: 600;">{source_url}</code>
            </div>

            <h3 style="font-size: 16px; color: #0f172a; margin-top: 24px; margin-bottom: 12px;">How to Add to SideStore for Auto-Updates:</h3>
            <ol style="font-size: 14px; line-height: 1.7; color: #334155; padding-left: 20px; margin: 0 0 20px 0;">
              <li>Open <strong>SideStore</strong> on your iPhone.</li>
              <li>Navigate to the <strong>Sources</strong> tab.</li>
              <li>Tap the <strong>+</strong> button in the top corner.</li>
              <li>Paste the source URL above.</li>
              <li>MindSpace will be added to your community sources. SideStore will detect <strong>v1.0.1 (Build 2)</strong> and allow one-tap updating!</li>
            </ol>
            
            <div style="text-align: center; margin: 28px 0;">
              <a href="{direct_ipa_url}" style="background-color: #7c3aed; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 14px; display: inline-block; box-shadow: 0 2px 4px rgba(124, 58, 237, 0.3);">Download Latest IPA Directly</a>
            </div>

            <hr style="border: 0; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
            
            <h4 style="font-size: 14px; color: #475569; margin: 0 0 10px 0;">Summary of Updates in v1.0.1:</h4>
            <ul style="font-size: 13px; line-height: 1.6; color: #64748b; padding-left: 20px; margin: 0;">
              <li><strong>Full-Screen Video Mode:</strong> Native full-screen video player for all course meditations.</li>
              <li><strong>Photorealistic Celestial Planet Art:</strong> 9 custom planetary graphics for each course category.</li>
              <li><strong>Dynamic Daily Recommendations:</strong> Next uncompleted session dynamically loads from your active course.</li>
              <li><strong>Daily Sleep Sounds:</strong> Rotating daily sleep sound with custom duration controls.</li>
              <li><strong>Background & Lock Screen Playback:</strong> Smooth audio persistence and Control Center lock screen controls.</li>
              <li><strong>Offline Data Portability:</strong> .mindspace export, clean restore, merge mode, and Compassion Pass streak protection.</li>
            </ul>
          </div>
          
          <div style="background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 16px 24px; text-align: center; font-size: 12px; color: #94a3b8;">
            MindSpace iOS • 100% Offline & Private Meditation
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
    send_update_email()
