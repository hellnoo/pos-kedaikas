-- =============================================
-- KedaiKas - Supabase Schema
-- Jalankan di SQL Editor Supabase
-- =============================================

-- TOKO (setiap UMKM punya 1 toko)
create table if not exists toko (
  id uuid default gen_random_uuid() primary key,
  nama text not null,
  alamat text,
  telepon text,
  email text unique not null,
  password_hash text not null,
  logo_emoji text default '☕',
  created_at timestamp default now()
);

-- PENGGUNA (kasir/owner per toko)
create table if not exists pengguna (
  id uuid default gen_random_uuid() primary key,
  toko_id uuid references toko(id) on delete cascade,
  nama text not null,
  role text default 'kasir', -- 'owner' | 'kasir'
  pin text not null,
  created_at timestamp default now()
);

-- MENU
create table if not exists menu (
  id uuid default gen_random_uuid() primary key,
  toko_id uuid references toko(id) on delete cascade,
  nama text not null,
  icon text default '🍽️',
  kategori text default 'Lainnya',
  harga integer not null,
  hpp integer default 0,
  status text default 'aktif',
  created_at timestamp default now()
);

-- BAHAN BAKU
create table if not exists bahan (
  id uuid default gen_random_uuid() primary key,
  toko_id uuid references toko(id) on delete cascade,
  nama text not null,
  satuan text default 'gram',
  stok numeric default 0,
  min_stok numeric default 0,
  harga_satuan numeric default 0,
  created_at timestamp default now()
);

-- RESEP (menu -> bahan)
create table if not exists resep (
  id uuid default gen_random_uuid() primary key,
  menu_id uuid references menu(id) on delete cascade,
  bahan_id uuid references bahan(id) on delete cascade,
  qty numeric not null
);

-- TRANSAKSI
create table if not exists transaksi (
  id uuid default gen_random_uuid() primary key,
  toko_id uuid references toko(id) on delete cascade,
  tanggal date default current_date,
  waktu text,
  items jsonb not null,
  total integer not null,
  total_hpp integer default 0,
  laba integer default 0,
  pembayaran text default 'cash',
  uang_diterima integer default 0,
  kembalian integer default 0,
  kasir_id uuid references pengguna(id),
  kasir_nama text,
  created_at timestamp default now()
);

-- RLS (Row Level Security) - data terisolasi per toko
alter table toko enable row level security;
alter table pengguna enable row level security;
alter table menu enable row level security;
alter table bahan enable row level security;
alter table resep enable row level security;
alter table transaksi enable row level security;

-- Policy: anon bisa baca/tulis semua (auth kita handle di app)
create policy "allow_all_toko" on toko for all using (true) with check (true);
create policy "allow_all_pengguna" on pengguna for all using (true) with check (true);
create policy "allow_all_menu" on menu for all using (true) with check (true);
create policy "allow_all_bahan" on bahan for all using (true) with check (true);
create policy "allow_all_resep" on resep for all using (true) with check (true);
create policy "allow_all_transaksi" on transaksi for all using (true) with check (true);
