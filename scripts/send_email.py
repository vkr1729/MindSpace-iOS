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
    msg["Subject"] = "MindSpace iOS v1.0.4 Released — Lock Screen & Background Audio Fixed"
    msg["From"] = f"MindSpace AI Assistant <{sender_email}>"
    msg["To"] = recipient_email
    
    vercel_web_url = "https://mindspace-ios.vercel.app"
    source_url = "https://mindspace-ios.vercel.app/apps.json"
    direct_ipa_url = "https://mindspace-ios.vercel.app/MindSpace.ipa"
    github_release_url = "https://github.com/vkr1729/MindSpace-iOS/releases/tag/latest"
    
    text_content = f"""Hi Kedar,

MindSpace iOS v1.0.4 (Build 5) is officially compiled, verified, and deployed to production!

=== WHAT WAS FIXED (LOCK SCREEN & BACKGROUND AUDIO) ===

1. Root Cause Identified & Resolved:
- The compiled IPA previously had UIBackgroundModes: None because Xcode automatic plist generation did not process the array format.
- iOS SpringBoard / mediaserverd immediately suspended audio playback when the phone was locked.
- We have created an explicit physical Info.plist specifying <key>UIBackgroundModes</key><array><string>audio</string></array> and enforced it in the build pipeline.

2. Audio Session & Control Center Routing:
- Added .allowBluetooth, .allowBluetoothA2DP, and .allowAirPlay category options to AudioSessionManager.
- Synchronized MPNowPlayingInfoCenter.default().playbackState on iOS 13+ for instant lock screen play/pause response.
- Added automated CI verification to strictly check the compiled IPA's Info.plist and prevent regressions.

3. Complete UI/UX Pro Max Redesign Included:
- Celestial breathing visualizer (6 breaths/min relaxation pulse)
- Luminous touch-responsive scrubber with live drag bubble
- Tactile Taptic engine feedback (HapticService)
- Unified Cosmic Orbit Hero and living constellation starlight paths

4. Download & SideStore Links:
- Direct Web Page: {vercel_web_url}
- Direct IPA Download: {direct_ipa_url}
- SideStore / AltStore Community Source: {source_url}
- GitHub Releases Page: {github_release_url}

Best regards,
MindSpace AI Assistant
"""

    html_content = f"""
    <html>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1e293b; background-color: #0b0d17; padding: 24px;">
        <div style="max-width: 620px; margin: 0 auto; background: #121528; border-radius: 20px; border: 1px solid rgba(124, 58, 237, 0.3); overflow: hidden; box-shadow: 0 16px 40px rgba(0,0,0,0.6);">
          <div style="background: linear-gradient(135deg, #064e3b, #059669, #10b981); padding: 36px 24px; text-align: center;">
            <h1 style="color: #ffffff; margin: 0; font-size: 26px; font-weight: 700; letter-spacing: -0.5px;">MindSpace iOS v1.0.4</h1>
            <p style="color: #d1fae5; margin: 8px 0 0 0; font-size: 14px; font-weight: 500;">Lock Screen & Background Audio Fixed • UI/UX Pro Max</p>
          </div>
          
          <div style="padding: 28px 24px; color: #f1f5f9;">
            <p style="font-size: 15px; line-height: 1.6; margin-top: 0;">Hi Kedar,</p>
            <p style="font-size: 15px; line-height: 1.6; color: #cbd5e1;">The lock screen background playback issue has been diagnosed via systematic debugging, completely resolved, verified in the compiled binary, and deployed as <strong>MindSpace iOS v1.0.4 (Build 5)</strong>.</p>
            
            <div style="background: #1a1e38; border-left: 4px solid #10b981; padding: 18px; border-radius: 12px; margin: 22px 0;">
              <h4 style="margin: 0 0 10px 0; color: #6ee7b7; font-size: 15px;">🔍 Root Cause & Technical Fix:</h4>
              <ul style="margin: 0; padding-left: 18px; font-size: 13px; color: #e2e8f0; line-height: 1.7;">
                <li><strong>Root Cause:</strong> The compiled binary was previously missing the <code>UIBackgroundModes: [audio]</code> entitlement because Xcode's auto-generated plist ignored the build setting string. iOS suspended the audio engine immediately upon screen lock.</li>
                <li><strong>Fixed Entitlement:</strong> Implemented a physical <code>Info.plist</code> with <code>UIBackgroundModes: ['audio']</code>, guaranteed and verified in the compiled IPA bundle.</li>
                <li><strong>Hardware Audio Routing:</strong> Added <code>.allowBluetooth</code>, <code>.allowBluetoothA2DP</code>, and <code>.allowAirPlay</code> for seamless playback over AirPods and wireless speakers.</li>
                <li><strong>Lock Screen State Sync:</strong> Synchronized <code>MPNowPlayingInfoCenter.default().playbackState</code> on iOS 13+ so the play/pause button state never desyncs.</li>
              </ul>
            </div>

            <div style="text-align: center; margin: 28px 0;">
              <a href="{direct_ipa_url}" style="background: linear-gradient(135deg, #10b981, #059669); color: #ffffff; padding: 15px 32px; text-decoration: none; border-radius: 12px; font-weight: 700; font-size: 15px; display: inline-block; box-shadow: 0 6px 20px rgba(16, 185, 129, 0.45);">Download MindSpace.ipa v1.0.4 (8.3 MB)</a>
            </div>

            <div style="background: #181b33; border: 1px solid rgba(255,255,255,0.08); padding: 16px; border-radius: 12px; margin: 24px 0;">
              <h3 style="margin: 0 0 6px 0; font-size: 12px; text-transform: uppercase; color: #94a3b8; letter-spacing: 0.5px;">SideStore / AltStore Community Source</h3>
              <code style="font-family: monospace; font-size: 13px; color: #34d399; word-break: break-all; font-weight: 600;">{source_url}</code>
            </div>

            <h3 style="font-size: 15px; color: #f8fafc; margin-top: 24px; margin-bottom: 10px;">Direct Links:</h3>
            <ul style="font-size: 14px; line-height: 1.8; color: #cbd5e1; padding-left: 20px; margin: 0 0 20px 0;">
              <li><strong>Web Portal:</strong> <a href="{vercel_web_url}" style="color: #34d399; font-weight: 600;">{vercel_web_url}</a></li>
              <li><strong>Private GitHub Release:</strong> <a href="{github_release_url}" style="color: #34d399; font-weight: 600;">GitHub Releases (Latest)</a></li>
            </ul>
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
    send_update_email()
