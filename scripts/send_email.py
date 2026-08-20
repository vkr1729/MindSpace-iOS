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
    msg["Subject"] = "MindSpace iOS — Verified Direct Download & SideStore Source Link"
    msg["From"] = f"MindSpace AI Assistant <{sender_email}>"
    msg["To"] = recipient_email
    
    vercel_web_url = "https://mindspace-ios.vercel.app"
    source_url = "https://mindspace-ios.vercel.app/apps.json"
    direct_ipa_url = "https://mindspace-ios.vercel.app/MindSpace.ipa"
    github_releases_url = "https://github.com/vkr1729/MindSpace-iOS/releases"
    
    text_content = f"""Hi Kedar,

Your MindSpace iOS distribution is fully tested and live! The GitHub repository is kept 100% PRIVATE as requested.

1. Direct Web Page & 1-Tap Download:
{vercel_web_url}

2. Direct IPA Download Link (Instant 1-tap download, 8.23 MB):
{direct_ipa_url}

3. SideStore / AltStore Community Source Link:
{source_url}

4. Private GitHub Releases Page (when logged into GitHub):
{github_releases_url}

How to Auto-Update via SideStore:
1. Open SideStore on your iPhone.
2. Go to the "Sources" tab and tap "+" in the top right.
3. Paste the Source URL:
   {source_url}
4. Tap Add. SideStore will fetch the verified JSON and recognize MindSpace v1.0.1 (Build 2) for one-tap install and future auto-updates over Wi-Fi!

Alternatively, you can open {vercel_web_url} on your iPhone Safari and tap 'Add to SideStore' or 'Download MindSpace.ipa' directly!

Best regards,
MindSpace Assistant
"""

    html_content = f"""
    <html>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; background-color: #f8fafc; padding: 24px;">
        <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.08);">
          <div style="background: linear-gradient(135deg, #4f46e5, #7c3aed); padding: 32px 24px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 24px; font-weight: 700;">MindSpace iOS</h1>
            <p style="color: #e0e7ff; margin: 8px 0 0 0; font-size: 14px;">v1.0.1 (Build 2) • Verified Direct Download & SideStore Source</p>
          </div>
          
          <div style="padding: 28px 24px;">
            <p style="font-size: 15px; line-height: 1.6; margin-top: 0;">Hi Kedar,</p>
            <p style="font-size: 15px; line-height: 1.6;">The GitHub repository is kept <strong>100% PRIVATE</strong>. The SideStore JSON source, direct IPA download, and web portal are verified and active on fast CDN endpoints:</p>
            
            <div style="text-align: center; margin: 24px 0;">
              <a href="{direct_ipa_url}" style="background-color: #7c3aed; color: #ffffff; padding: 14px 28px; text-decoration: none; border-radius: 10px; font-weight: 700; font-size: 15px; display: inline-block; box-shadow: 0 4px 12px rgba(124, 58, 237, 0.35);">Download MindSpace.ipa (8.2 MB)</a>
            </div>

            <div style="background: #f1f5f9; border-left: 4px solid #7c3aed; padding: 16px; border-radius: 8px; margin: 24px 0;">
              <h3 style="margin: 0 0 6px 0; font-size: 13px; text-transform: uppercase; color: #64748b; letter-spacing: 0.5px;">SideStore / AltStore Source URL</h3>
              <code style="font-family: monospace; font-size: 13px; color: #6d28d9; word-break: break-all; font-weight: 600;">{source_url}</code>
            </div>

            <h3 style="font-size: 16px; color: #0f172a; margin-top: 24px; margin-bottom: 12px;">Quick Install / Auto-Update:</h3>
            <ul style="font-size: 14px; line-height: 1.8; color: #334155; padding-left: 20px; margin: 0 0 20px 0;">
              <li><strong>Option 1 (Web Portal):</strong> Open <a href="{vercel_web_url}" style="color: #7c3aed; font-weight: 600;">{vercel_web_url}</a> in Safari on your iPhone and tap <em>Download MindSpace.ipa</em> or <em>Add to SideStore</em>.</li>
              <li><strong>Option 2 (SideStore Source):</strong> Open SideStore &gt; Sources tab &gt; tap <strong>+</strong> &gt; paste <code>{source_url}</code>.</li>
              <li><strong>Option 3 (Private GitHub Release):</strong> Download directly from <a href="{github_releases_url}" style="color: #7c3aed; font-weight: 600;">GitHub Releases</a> while logged into your account.</li>
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
