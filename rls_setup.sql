-- ============================================================
-- KEDAIKAS — RLS SETUP
-- Jalankan seluruh script ini di Supabase SQL Editor
-- ============================================================

-- 1. Tambah kolom auth ke tabel toko
ALTER TABLE toko ADD COLUMN IF NOT EXISTS auth_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE toko ADD COLUMN IF NOT EXISTS auth_email    text;
ALTER TABLE toko ADD COLUMN IF NOT EXISTS auth_password text;

-- 2. Helper function: return toko_id milik user yang sedang login
CREATE OR REPLACE FUNCTION my_toko_id()
RETURNS uuid LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT id FROM toko WHERE auth_id = auth.uid() LIMIT 1;
$$;

-- 3. Enable RLS semua tabel
ALTER TABLE toko         ENABLE ROW LEVEL SECURITY;
ALTER TABLE pengguna     ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu         ENABLE ROW LEVEL SECURITY;
ALTER TABLE bahan        ENABLE ROW LEVEL SECURITY;
ALTER TABLE resep        ENABLE ROW LEVEL SECURITY;
ALTER TABLE transaksi    ENABLE ROW LEVEL SECURITY;
ALTER TABLE stok_keluar  ENABLE ROW LEVEL SECURITY;
ALTER TABLE kas_shift    ENABLE ROW LEVEL SECURITY;
ALTER TABLE setoran_kas  ENABLE ROW LEVEL SECURITY;

-- 4. Drop policies lama kalau ada (termasuk allow_all_* dari setup sebelumnya)
DROP POLICY IF EXISTS toko_sel         ON toko;
DROP POLICY IF EXISTS toko_ins         ON toko;
DROP POLICY IF EXISTS toko_upd         ON toko;
DROP POLICY IF EXISTS toko_del         ON toko;
DROP POLICY IF EXISTS pg_rls           ON pengguna;
DROP POLICY IF EXISTS mn_rls           ON menu;
DROP POLICY IF EXISTS bh_rls           ON bahan;
DROP POLICY IF EXISTS rs_rls           ON resep;
DROP POLICY IF EXISTS tx_rls           ON transaksi;
DROP POLICY IF EXISTS sk_rls           ON stok_keluar;
DROP POLICY IF EXISTS ks_rls           ON kas_shift;
DROP POLICY IF EXISTS st_rls           ON setoran_kas;

-- Drop allow_all_* policies lama
DROP POLICY IF EXISTS allow_all_toko        ON toko;
DROP POLICY IF EXISTS allow_all_pengguna    ON pengguna;
DROP POLICY IF EXISTS allow_all_menu        ON menu;
DROP POLICY IF EXISTS allow_all_bahan       ON bahan;
DROP POLICY IF EXISTS allow_all_resep       ON resep;
DROP POLICY IF EXISTS allow_all_transaksi   ON transaksi;
DROP POLICY IF EXISTS allow_all_stok_keluar ON stok_keluar;
DROP POLICY IF EXISTS allow_all_kas_shift   ON kas_shift;
DROP POLICY IF EXISTS allow_all_setoran_kas ON setoran_kas;

-- 5. TOKO policies
--    SELECT public → biar bisa cari toko by name di reconnect
CREATE POLICY toko_sel ON toko FOR SELECT USING (true);
--    INSERT: boleh kalau auth_id cocok (registrasi baru)
CREATE POLICY toko_ins ON toko FOR INSERT WITH CHECK (auth_id = auth.uid());
--    UPDATE/DELETE: hanya pemilik
CREATE POLICY toko_upd ON toko FOR UPDATE USING (auth_id = auth.uid());
CREATE POLICY toko_del ON toko FOR DELETE USING (auth_id = auth.uid());

-- 6. Semua tabel lain: akses via my_toko_id()
--    Catatan: ada "escape hatch" untuk toko lama yang auth_id-nya belum diset
--    (auth_id IS NULL) → masih bisa diakses sampai owner reconnect dan update credentials.
--    Hapus kondisi "OR..." setelah semua toko sudah migrasi.

CREATE POLICY pg_rls ON pengguna FOR ALL USING (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
) WITH CHECK (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
);

CREATE POLICY mn_rls ON menu FOR ALL USING (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
) WITH CHECK (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
);

CREATE POLICY bh_rls ON bahan FOR ALL USING (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
) WITH CHECK (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
);

CREATE POLICY rs_rls ON resep FOR ALL USING (
  EXISTS (
    SELECT 1 FROM menu m WHERE m.id = resep.menu_id AND (
      m.toko_id = my_toko_id()
      OR EXISTS (SELECT 1 FROM toko t WHERE t.id = m.toko_id AND t.auth_id IS NULL)
    )
  )
);

CREATE POLICY tx_rls ON transaksi FOR ALL USING (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
) WITH CHECK (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
);

CREATE POLICY sk_rls ON stok_keluar FOR ALL USING (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
) WITH CHECK (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
);

CREATE POLICY ks_rls ON kas_shift FOR ALL USING (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
) WITH CHECK (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
);

CREATE POLICY st_rls ON setoran_kas FOR ALL USING (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
) WITH CHECK (
  toko_id = my_toko_id()
  OR EXISTS (SELECT 1 FROM toko t WHERE t.id = toko_id AND t.auth_id IS NULL)
);

-- 7. Fungsi RECONNECT — SECURITY DEFINER (bypass RLS, verifikasi PIN owner)
CREATE OR REPLACE FUNCTION reconnect_toko(p_toko_id uuid, p_pin_hash text)
RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toko    toko%ROWTYPE;
  v_owner   pengguna%ROWTYPE;
  v_match   boolean := false;
BEGIN
  -- Cari owner dengan PIN yang cocok (support SHA-256 + base64 legacy)
  SELECT * INTO v_owner
  FROM pengguna
  WHERE toko_id = p_toko_id
    AND role = 'owner'
    AND pin = p_pin_hash
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PIN salah atau bukan owner';
  END IF;

  SELECT * INTO v_toko FROM toko WHERE id = p_toko_id;

  IF v_toko.auth_email IS NULL THEN
    RAISE EXCEPTION 'Toko belum memiliki akun auth. Hubungi admin.';
  END IF;

  RETURN json_build_object(
    'auth_email',    v_toko.auth_email,
    'auth_password', v_toko.auth_password
  );
END;
$$;

-- 8. Grant execute pada fungsi ke anon (diperlukan agar bisa dipanggil tanpa login)
GRANT EXECUTE ON FUNCTION reconnect_toko(uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION my_toko_id() TO anon, authenticated;

-- 9. Fungsi REGISTER_TOKO — bypass email confirmation
--    Membuat auth user (langsung confirmed) + identity + toko + pengguna owner sekaligus
CREATE OR REPLACE FUNCTION register_toko(
  p_nama_toko    text,
  p_nama_owner   text,
  p_auth_email   text,
  p_auth_password text
) RETURNS json LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id  uuid := gen_random_uuid();
  v_toko_id  uuid;
  v_enc_pw   text;
BEGIN
  -- Hash password pakai bcrypt (pgcrypto, sudah enable di Supabase)
  v_enc_pw := crypt(p_auth_password, gen_salt('bf'));

  -- Buat auth user langsung (email sudah confirmed, tidak perlu konfirmasi email)
  INSERT INTO auth.users (
    id, instance_id, aud, role,
    email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, confirmation_token, recovery_token,
    email_change_token_new, email_change
  ) VALUES (
    v_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated',
    p_auth_email, v_enc_pw,
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}', '{}',
    false, '', '', '', ''
  );

  -- Buat auth identity (wajib agar signInWithPassword bisa bekerja)
  INSERT INTO auth.identities (
    id, provider_id, user_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), p_auth_email, v_user_id,
    json_build_object('sub', v_user_id::text, 'email', p_auth_email),
    'email',
    now(), now(), now()
  );

  -- Buat toko
  INSERT INTO toko (nama, auth_id, auth_email, auth_password)
  VALUES (p_nama_toko, v_user_id, p_auth_email, p_auth_password)
  RETURNING id INTO v_toko_id;

  -- Buat pengguna owner (PIN diset nanti lewat layar aktivasi)
  INSERT INTO pengguna (nama, role, pin, toko_id)
  VALUES (p_nama_owner, 'owner', 'PENDING', v_toko_id);

  RETURN json_build_object(
    'toko_id',  v_toko_id,
    'user_id',  v_user_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION register_toko(text,text,text,text) TO anon;

-- ============================================================
-- SELESAI.
-- ============================================================
