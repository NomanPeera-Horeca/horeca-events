# Deployment Guide: Step by Step

This is exactly what you asked for. The exact sequence. No fluff.

---

## 🎯 The Big Picture

You have **3 things to deploy**:

| What | Where | Type |
|---|---|---|
| **Public site** (`/horeca-events/index.html`) | GitHub Pages OR Render | **Static site** |
| **Admin panel** (`/horeca-backend/frontend/admin.html`) | GitHub Pages OR Render | **Static site** |
| **Edge function** (`/horeca-backend/edge-functions/`) | Supabase | Deno (deployed via CLI) |

Plus database setup in Supabase.

---

## ✅ Render: Web Service or Static Site?

**Answer: STATIC SITE for both** the public site and admin panel.

### Why Static, not Web Service?

- **Static sites** = HTML/CSS/JS files served directly. Free forever on Render. Instant deploy. CDN cached. No server, no cost.
- **Web Service** = Node/Python backend running 24/7. Costs money, slower, unnecessary for what we are building. We do not need this because Supabase IS the backend.

### How both work together:

```
┌─────────────────────────────────┐
│  GitHub Pages (static site)     │  ← Public form
│  events.thehorecastore.com      │
│  └─ index.html                  │
└─────────┬───────────────────────┘
          │ submits to →
          ▼
┌─────────────────────────────────┐
│  SUPABASE (database + functions)│  ← Backend
│  └─ Postgres + Edge Functions   │
└─────────┬───────────────────────┘
          ▲
          │ reads/writes from →
┌─────────┴───────────────────────┐
│  Render Static Site (private)   │  ← Admin panel
│  admin.thehorecastore.com       │
│  └─ admin.html                  │
└─────────────────────────────────┘
```

The static sites are just files. Supabase does all the heavy lifting.

---

## 📋 THE EXACT SEQUENCE: Step 1 through 10

### 🟢 STEP 1: Set Up Supabase (10 min)

1. Go to **supabase.com → New Project**
2. Name: `horeca-meetup`
3. Generate strong DB password → save to 1Password
4. Region: **East US** (closest to Houston)
5. Wait ~2 min for provisioning
6. **Copy these 3 values from Settings → API:**
   - `Project URL` (looks like `https://abc123xyz.supabase.co`)
   - `anon public` key
   - `service_role` key (KEEP SECRET; never put in frontend)

✅ **Done when:** You have those 3 values saved.

---

### 🟢 STEP 2: Run Database Schema (5 min)

1. In Supabase → **SQL Editor → New Query**
2. Open `/horeca-backend/database/schema.sql`
3. Copy entire contents → paste in SQL Editor
4. Click **Run**
5. Should say "Success"

6. **Then run the seed file:**
   - New Query
   - Open `/horeca-backend/database/seed-templates.sql`
   - Copy → paste → Run

✅ **Done when:** Table Editor shows `events` (6 rows), `registrations` (empty), `email_templates` (11 rows), `admin_users` (1 row), `activity_log` (empty).

---

### 🟢 STEP 3: Update Admin Email (1 min)

The schema seeds your email as `noman@thehorecastore.com`. If your real email differs:

1. Supabase → **Table Editor → admin_users**
2. Click the row → edit email field
3. Save

✅ **Done when:** Your real email is in the `admin_users` table.

---

### 🟢 STEP 4: Create Storage Bucket for QR Codes (3 min)

1. Supabase → **Storage** in left sidebar
2. Click **New bucket**
3. Name: `qr-codes`
4. Public bucket: **YES** (toggle ON; critical for emails to display QR)
5. File size limit: 1 MB
6. Allowed MIME types: `image/png`
7. Click **Create**

✅ **Done when:** `qr-codes` bucket exists and is marked public.

---

### 🟢 STEP 5: Paste Email Template HTML (10 min)

The seed file created 11 template rows but their `body_html` is empty. You need to paste the actual HTML.

For each row in `email_templates`, paste the corresponding HTML:

| Template Slug | Source File | Notes |
|---|---|---|
| `approval` | `/emails/approval.html` | Whole file |
| `approval-plus-one` | `/emails/approval-plus-one.html` | Whole file (NEW; for guest emails) |
| `rejection-fully-booked` | `/emails/rejection.html` | Variant 1 (the active HTML at top) |
| `rejection-not-fit` | `/emails/rejection.html` | Variant 2 body in a copy of the template |
| `rejection-future-edition` | `/emails/rejection.html` | Variant 3 body in a copy of the template |
| `question-business-details` | `/emails/question.html` | Whole file |
| `question-role-clarification` | `/emails/question.html` | Same file, different `custom_message` |
| `reminder-2weeks` | `/emails/reminders.html` | Variant 1 (active HTML) |
| `reminder-1week` | `/emails/reminders.html` | Variant 2 body |
| `reminder-day-before` | `/emails/reminders.html` | Variant 3 body |
| `reminder-day-of` | `/emails/reminders.html` | Variant 4 body |

**How to paste:**
1. Open the file (`/emails/approval.html` etc.) in a text editor
2. Select all → Copy
3. Supabase → Table Editor → email_templates → click the row → edit `body_html` → paste → Save

✅ **Done when:** All 11 rows have HTML in their `body_html` column.

---

### 🟢 STEP 6: Create Auth User for Admin Login (2 min)

1. Supabase → **Authentication → Users → Add User → Send invite**
2. Email: same as in `admin_users` table
3. Auto Confirm User: **YES**
4. Send invitation: **NO** (set password directly is faster)
5. Click "Add user"
6. Then click that user → **Reset password** → set a strong password

✅ **Done when:** You can log into Supabase Auth with that email + password.

---

### 🟢 STEP 7: Deploy Edge Function (15 min)

This is done from your terminal in Cursor:

```bash
# 1. Install Supabase CLI (Mac)
brew install supabase/tap/supabase

# 2. In a new folder
mkdir horeca-supabase && cd horeca-supabase
supabase init
supabase login

# 3. Link to your project
supabase link --project-ref YOUR_PROJECT_ID
# (find YOUR_PROJECT_ID in your Supabase URL: https://YOUR_PROJECT_ID.supabase.co)

# 4. Create the function
supabase functions new send-registration-email

# 5. Replace the generated index.ts contents with /horeca-backend/edge-functions/send-registration-email/index.ts

# 6. Set secrets (get keys from Resend → API Keys)
supabase secrets set RESEND_API_KEY=re_YOUR_KEY
supabase secrets set FROM_EMAIL=events@thehorecastore.com
supabase secrets set FROM_NAME="The Horeca Meetup"

# 7. Deploy
supabase functions deploy send-registration-email --no-verify-jwt
```

You should see: `Deployed Function send-registration-email`

✅ **Done when:** Function appears in Supabase → Edge Functions list.

---

### 🟢 STEP 8: Update index.html with Supabase Credentials (5 min)

1. Open `/horeca-events/index.html` in Cursor
2. Find this section near the bottom (around line 1550):

```javascript
const SUPABASE_URL = 'https://YOUR_PROJECT_ID.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_PUBLIC_ANON_KEY_HERE';
```

3. Replace both with the real values from Step 1
4. Save

✅ **Done when:** Both placeholders are replaced with real Supabase URL and anon key.

---

### 🟢 STEP 9: Update admin.html with Same Credentials (3 min)

1. Open `/horeca-backend/frontend/admin.html`
2. Find the same `SUPABASE_URL` and `SUPABASE_ANON_KEY` lines (top of `<script>`)
3. Paste the same values
4. Save

✅ **Done when:** admin.html has the credentials.

---

### 🟢 STEP 10: Push to GitHub & Deploy on Render (10 min)

You have **2 separate sites** to deploy.

#### A) Public Site (events.thehorecastore.com)

You probably already have this on GitHub Pages. If so:

1. Replace `index.html` in your GitHub repo with the updated one from `/horeca-events/index.html`
2. Push to main → GitHub Pages auto-deploys

If you want to use Render instead:

1. Push `/horeca-events/` folder to a GitHub repo (private OK)
2. Render → **New → Static Site**
3. Connect that repo
4. Build command: leave blank
5. Publish directory: `.` (root) or wherever index.html is
6. Custom domain: `events.thehorecastore.com`

#### B) Admin Panel (admin.thehorecastore.com)

**Use a separate private GitHub repo for security:**

1. Create new private repo: `horeca-admin`
2. Inside it, create a folder structure:
   ```
   /
   └── index.html  (rename admin.html → index.html)
   ```
3. Push to GitHub
4. Render → **New → Static Site**
5. Connect the `horeca-admin` repo
6. Build command: leave blank
7. Publish directory: `.`
8. Custom domain: `admin.thehorecastore.com`
9. **In Render Settings → Add Environment Protection** (basic auth) for extra security

✅ **Done when:** Both URLs load correctly.

---

## 🧪 STEP 11: Test the Full Flow (5 min)

1. Open `events.thehorecastore.com`
2. Click "Reserve Your Seat" → fill form with **your real email**
3. Toggle "Add a guest" ON → fill in a **second real email** (use a friend's, or another inbox you own)
4. Submit

5. Open `admin.thehorecastore.com`
6. Sign in with admin credentials from Step 6
7. You should see your test registration in **Pending**
8. Click **✓ Approve** → choose template "Approval · Main Attendee" → click "Approve & Send Email"

9. Check email:
   - **Your email** should receive: "You are confirmed for The Horeca Meetup..."
   - **Guest email** should receive: "Noman registered you for The Horeca Meetup..."
   - Both should have working QR codes

🎉 **If both emails arrive: YOU ARE LIVE.**

---

## 🆘 Troubleshooting

| Problem | Solution |
|---|---|
| Form submits but no row in Supabase | Check browser console. Verify SUPABASE_URL and ANON_KEY are correct. Check RLS policy allows public INSERT. |
| Cannot log into admin | Email in `admin_users` must EXACTLY match the email in Supabase Auth. |
| Approval email not sent | Check Supabase Edge Function logs: `supabase functions logs send-registration-email`. Verify Resend domain is verified. Verify RESEND_API_KEY is set. |
| QR shows broken image in email | Make sure `qr-codes` bucket is set to PUBLIC. Open the QR URL directly; it should display. |
| Plus-one email not sent | Verify `approval-plus-one` template exists in `email_templates` table with HTML. The Edge Function looks up this slug. |

---

## 📊 What You Now Have

✅ Real database: every form submission persisted forever  
✅ Admin panel: see who registered, approve/reject/ask with one click  
✅ Email automation: branded emails from `events@thehorecastore.com`  
✅ **Plus-One support:** guests get their own personal email saying "Noman registered you"  
✅ QR codes: auto-generated on approval, separate QR for guest  
✅ Brand consistency: every email has identical header + footer  
✅ Audit trail: every action logged in `activity_log`  
✅ Multi-event support: Vol. III, Vol. IV, Vol. VIII Dubai all from one panel  
✅ Capacity tracking: auto-flags when event hits 100  
✅ UTM tracking: see which channel drove the RSVP  

This is conference-grade infrastructure. Same architecture as Aspire, Inman, Saastr.

---

## 💰 Cost: $0/month

| Service | Tier | Your Usage |
|---|---|---|
| Supabase | Free (500MB DB, 1GB storage, 500K requests) | <5% |
| Resend | Free (3,000 emails/mo, 100/day) | <10% |
| GitHub Pages | Free unlimited | Free |
| Render Static Sites | Free unlimited | Free |

You scale to thousands of RSVPs before paying anything.

---

## 🚀 Ready to Build Vol. III at Scale

When you are ready to chase Yum Brands CEO and Cava CEO as Vol. V/VI speakers, this infrastructure will already look the part. They will see:

- Branded confirmation emails  
- QR-coded entry  
- Multi-edition track record (Vol. I → Vol. VIII)  
- Real CRM with audit trail  
- Pro check-in system  

That signals **"this is a serious series"**, not "this is a Houston supplier hosting a meetup."

Ship it.

---

Built for Noman Peera · The Horeca Meetup · Houston / Los Angeles / Dubai
