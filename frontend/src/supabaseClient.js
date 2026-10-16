// =============================================================================
// supabaseClient.js
// Supabase JS client singleton — import this into every component.
// SETUP: Replace the two placeholder strings below with your actual project
//        credentials from: Supabase Dashboard → Settings → API
// =============================================================================
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL  = 'YOUR_SUPABASE_URL';   // e.g. https://xyzabcdef.supabase.co
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY'; // starts with "eyJ..."

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
