-- =============================================
-- KedaiKas — Premium QRIS + Moota Integration
-- Jalankan di Supabase → SQL Editor
-- =============================================

-- Tambah kolom premium ke tabel toko
ALTER TABLE toko ADD COLUMN IF NOT EXISTS is_premium    BOOLEAN DEFAULT FALSE;
ALTER TABLE toko ADD COLUMN IF NOT EXISTS moota_bank_id TEXT;
ALTER TABLE toko ADD COLUMN IF NOT EXISTS qris_string   TEXT;

-- Tabel pending QRIS (menunggu konfirmasi Moota)
CREATE TABLE IF NOT EXISTS pending_qris (
  id            UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
  toko_id       UUID      NOT NULL REFERENCES toko(id) ON DELETE CASCADE,
  kasir_id      TEXT,
  kasir_nama    TEXT,
  amount        INTEGER   NOT NULL,         -- nominal asli (sebelum suffix unik)
  unique_amount INTEGER   NOT NULL,         -- nominal unik yang ditampilkan ke customer
  cart_items    JSONB     DEFAULT '[]',     -- snapshot cart
  total_hpp     INTEGER   DEFAULT 0,
  status        TEXT      DEFAULT 'pending' CHECK (status IN ('pending','confirmed','expired')),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at  TIMESTAMPTZ
);

-- RLS
ALTER TABLE pending_qris ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_pending_qris" ON pending_qris
  FOR ALL USING (true) WITH CHECK (true);

-- Aktifkan Realtime untuk pending_qris
-- (Supabase Dashboard → Database → Replication → enable pending_qris)
-- atau jalankan:
ALTER PUBLICATION supabase_realtime ADD TABLE pending_qris;

-- Auto-expire pending QRIS yang lebih dari 35 menit (opsional, jalankan via pg_cron)
-- Aktifkan pg_cron di Extensions jika ingin pakai ini:
-- SELECT cron.schedule('expire-pending-qris', '*/10 * * * *', $$
--   UPDATE pending_qris SET status='expired'
--   WHERE status='pending' AND created_at < NOW() - INTERVAL '35 minutes';
-- $$);
