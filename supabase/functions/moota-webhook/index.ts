/**
 * KedaiKas — Moota Webhook Handler
 * Supabase Edge Function
 *
 * Deploy:
 *   supabase functions deploy moota-webhook --no-verify-jwt
 *
 * Set env vars di Supabase Dashboard → Settings → Edge Functions:
 *   MOOTA_WEBHOOK_SECRET = (random string, sama dengan yang kamu set di Moota)
 *
 * Webhook URL di Moota (Settings → Webhook):
 *   https://ashhcapfjxnjwqvsyjhb.supabase.co/functions/v1/moota-webhook?token=YOUR_SECRET
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type, x-moota-token, authorization',
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    // Verifikasi token (keamanan dasar)
    const url   = new URL(req.url)
    const token = url.searchParams.get('token')
    const secret = Deno.env.get('MOOTA_WEBHOOK_SECRET')
    if (secret && token !== secret) return json({ error: 'Unauthorized' }, 401)

    const body = await req.json()

    // Moota bisa kirim array atau object langsung
    const mutations: Record<string, unknown>[] =
      Array.isArray(body)       ? body       :
      Array.isArray(body?.data) ? body.data  :
      [body]

    const sb = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const results = []

    for (const mut of mutations) {
      const typeRaw = String(mut.mutation_type ?? mut.type ?? '').toUpperCase()
      const isCr = typeRaw === 'CR' || typeRaw === 'CREDIT' || typeRaw === 'IN'

      // Lewati debit / bukan uang masuk
      if (!isCr) {
        results.push({ skipped: 'debit', amount: mut.amount })
        continue
      }

      const amount = parseInt(String(mut.amount ?? 0))
      if (!amount || amount <= 0) continue

      // Cari pending_qris yang cocok (dalam 35 menit terakhir)
      const cutoff = new Date(Date.now() - 35 * 60 * 1000).toISOString()
      const { data: pending } = await sb
        .from('pending_qris')
        .select('*')
        .eq('unique_amount', amount)
        .eq('status', 'pending')
        .gte('created_at', cutoff)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      if (!pending) {
        results.push({ skipped: 'no_match', amount })
        continue
      }

      // Tandai sebagai confirmed → Realtime akan trigger app
      await sb
        .from('pending_qris')
        .update({ status: 'confirmed', confirmed_at: new Date().toISOString() })
        .eq('id', pending.id)

      // Insert transaksi ke DB (Edge Function pakai service role, bisa bypass RLS)
      const now   = new Date()
      const today = now.toISOString().slice(0, 10)
      const time  = now.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })

      const { error: txErr } = await sb.from('transaksi').insert({
        toko_id      : pending.toko_id,
        tanggal      : today,
        waktu        : time,
        items        : pending.cart_items ?? [],
        total        : pending.amount,          // nominal asli (tanpa suffix)
        total_hpp    : pending.total_hpp ?? 0,
        laba         : pending.amount - (pending.total_hpp ?? 0),
        pembayaran   : 'qris',
        uang_diterima: amount,                  // nominal unik yang masuk
        kembalian    : 0,
        kasir_id     : pending.kasir_id,
        kasir_nama   : pending.kasir_nama,
        catatan      : '⚡ Auto-konfirmasi Moota',
      })

      if (txErr) {
        results.push({ error: txErr.message, pending_id: pending.id })
      } else {
        results.push({ confirmed: pending.id, amount, toko_id: pending.toko_id })
        console.log(`✅ QRIS confirmed: Rp${amount} → toko ${pending.toko_id}`)
      }
    }

    return json({ ok: true, processed: mutations.length, results })

  } catch (e) {
    console.error('Moota webhook error:', e)
    return json({ error: (e as Error).message }, 500)
  }
})
