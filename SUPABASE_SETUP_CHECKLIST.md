# SpaceSense AI - Supabase Setup Checklist

**Date:** November 5, 2026  
**Project:** SpaceSense AI - Room Analysis App

---

## ✅ Setup Checklist

### 1. Create Supabase Account & Project

- [ ] Go to https://supabase.com
- [ ] Click "Start your project" or "Sign Up"
- [ ] Sign up with GitHub or Email
- [ ] In Dashboard, click "New project"
- [ ] Fill in:
  - Organization: Personal
  - Name: `spacesense-ai`
  - Database Password: Generate and **SAVE IT** (store in password manager)
  - Region: Choose closest to you
  - Pricing Plan: **Free**
- [ ] Click "Create new project"
- [ ] Wait ~2 minutes for provisioning

---

### 2. Get API Credentials

- [ ] Go to **Settings → API** in left sidebar
- [ ] Copy these 3 values:

#### Project URL:
```
Example: https://abcdefghijklmnop.supabase.co
Your URL: ___________________________________
```

#### anon public key:
```
Example: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Your Key: ___________________________________
(Very long string, ~200+ characters)
```

---

### 3. Configure Authentication

- [ ] Go to **Authentication → Providers**
- [ ] Verify Email Auth is enabled (should be by default)
- [ ] Check these settings:
  - ✅ Enable email confirmations
  - ✅ Secure email change
- [ ] Click **Save**

---

### 4. Update Flutter App Configuration

**File:** `mobile/lib/core/config/env.dart`

- [ ] Open the file
- [ ] Replace `YOUR_SUPABASE_URL` with your Project URL from Step 2
- [ ] Replace `YOUR_SUPABASE_ANON_KEY` with your anon public key from Step 2
- [ ] Save the file

```dart
class Env {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
  static const bool isProduction = false;
  static const bool enableLogging = true;
}
```

---

### 5. Test Authentication Flow

#### Using the Flutter App

- [ ] Rebuild the app with updated credentials:
  ```bash
  cd mobile
  flutter build apk --split-per-abi --release
  ```
- [ ] Install on Android device:
  ```bash
  # Transfer APK and install manually, or:
  adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
  ```
- [ ] Open app
- [ ] Click "Sign Up"
- [ ] Enter email and password
- [ ] Check email for verification link
- [ ] Click verification link
- [ ] Login with credentials

---

### 8. Verify in Supabase Dashboard

- [ ] Go to **Authentication → Users** in Supabase Dashboard
- [ ] You should see your test user listed
- [ ] Status should be "Confirmed" after email verification

---

## 🎯 Success Criteria

✅ Supabase project created  
✅ All 3 credentials copied and saved  
✅ Flutter app updated with credentials  
✅ Backend updated with credentials  
✅ Backend running successfully at http://localhost:8000  
✅ Successfully created test user account  
✅ Email verification received and clicked  
✅ User appears in Supabase Dashboard  

---

## 📝 Important Notes

1. **Free Tier Limits:**
   - 500 MB database storage
   - 2 GB bandwidth per month
   - 50,000 monthly active users
   - Project pauses after 7 days of inactivity (auto-resumes on next request)

2. **Security:**
   - Your anon key is safe to use in the mobile app (it's public by design)
   - Keep your database password private

3. **Email Verification:**
   - By default, users must verify email before login
   - Check spam folder if verification email doesn't arrive
   - Can disable in: Authentication → Settings → "Enable email confirmations"

4. **Next Steps After Setup:**
   - Add your AI provider API key (Google Gemini has a free tier) in the app's
     Settings → API Configuration
   - You're ready — the app calls AI providers directly; no backend to deploy

---

## 🆘 Troubleshooting

### Issue: "Invalid API key" error
**Solution:** Double-check you copied the entire anon key (it's very long, ~200 characters)

### Issue: Email verification not received
**Solutions:**
1. Check spam/junk folder
2. In Supabase Dashboard → Authentication → Email Templates, click "Send test email"
3. Temporarily disable email verification: Authentication → Settings → uncheck "Enable email confirmations"

### Issue: "Project paused" error
**Solution:** Free tier projects pause after 7 days inactivity. Just make any request to auto-resume, or upgrade to paid plan.

---

## 📞 Support Resources

- Supabase Docs: https://supabase.com/docs
- Supabase Discord: https://discord.supabase.com
- Project Dashboard: https://supabase.com/dashboard/project/YOUR_PROJECT_ID

---

**Setup completed on:** ___________________  
**Tested by:** ___________________  
**Status:** ⬜ In Progress  /  ⬜ Complete
