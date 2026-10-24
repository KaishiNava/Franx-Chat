# FRANXX CHAT — Monochrome Premium

Flutter Android starter project for the FRANXX CHAT app.

## What's included in this first scaffold

- Monochrome premium UI (dark/light theme toggle)
- Login and registration screens connected to Supabase when configured
- Local demo mode if Supabase credentials have not been configured
- Dashboard, username search screen, local conversation screen, profile and settings
- SQLite local message history
- Clear local chat history action
- GitHub Actions workflow to build an Android APK in the cloud

> Important: In demo mode, accounts and messages are local demo data. They are not real online chat and cannot reach other users. Online search and delivery require Supabase setup and the SQL schema below. This starter does not yet implement complete online message delivery.

## Build APK from a phone using GitHub

1. Create a GitHub repository named `franxx-chat`.
2. Upload the contents of this ZIP to the repository root (not the ZIP file itself).
3. Ensure the default branch is named `main`.
4. Open **Actions** → **Build FRANXX CHAT APK** → **Run workflow** (or wait for the push workflow).
5. Open the completed workflow run and download the `franxx-chat-apk` artifact.
6. Extract the downloaded artifact ZIP and install `app-release.apk` on Android.

GitHub Actions usage is subject to GitHub's current plan limits.

## Configure Supabase

Create a Supabase project. Get the Project URL and publishable/anon key from the project's API settings. Do not use a `service_role` key in the app.

For local/cloud build, provide Dart defines to the build command:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

To pass these to GitHub Actions, add repository **Actions variables**:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Then add the following step before Build APK in `.github/workflows/build-apk.yml`:

```yaml
      - name: Build APK
        run: >-
          flutter build apk --release
          --dart-define=SUPABASE_URL=${{ vars.SUPABASE_URL }}
          --dart-define=SUPABASE_ANON_KEY=${{ vars.SUPABASE_ANON_KEY }}
```

Supabase publishable/anon keys are designed for client use, but database tables must be protected with Row Level Security (RLS). Never put a service-role secret in a mobile app.

## Starter SQL schema

Run in Supabase SQL Editor. Review and test RLS policies before using with real users.

```sql
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username = lower(username)),
  display_name text not null default '',
  bio text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are searchable by signed-in users"
on public.profiles for select to authenticated using (true);

create policy "Users can create their own profile"
on public.profiles for insert to authenticated
with check (auth.uid() = id);

create policy "Users can update their own profile"
on public.profiles for update to authenticated
using (auth.uid() = id) with check (auth.uid() = id);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) <= 5000),
  created_at timestamptz not null default now()
);

alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

create policy "Users can see their own memberships"
on public.conversation_members for select to authenticated
using (user_id = auth.uid());

create policy "Members can read messages"
on public.messages for select to authenticated
using (
  exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = auth.uid()
  )
);

create policy "Members can send messages as themselves"
on public.messages for insert to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = messages.conversation_id
      and cm.user_id = auth.uid()
  )
);
```

This is an initial schema scaffold, not a finished production security review. A secure conversation-creation flow and membership policies still need to be implemented before online messaging is enabled.
