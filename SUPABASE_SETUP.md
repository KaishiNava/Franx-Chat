# Supabase setup notes

1. Create a Supabase project.
2. In Authentication settings, configure email sign-up and email confirmation as you prefer.
3. Add `profiles`, `conversations`, `conversation_members`, and `messages` using the SQL in README.md.
4. Before enabling real chat, implement secure conversation creation and RLS policies for membership insert/update/delete.
5. Set GitHub repository Actions variables `SUPABASE_URL` and `SUPABASE_ANON_KEY` and adjust the workflow build step as described in README.md.

The current starter uses Supabase for auth when configured. The search list is demo data and message send is local-only, even if Supabase auth is configured. Online message delivery is a later development step.
