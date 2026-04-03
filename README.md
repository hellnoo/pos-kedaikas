# KedaiKas ☕ — Sistem Kasir UMKM Nusantara

Aplikasi POS (Point of Sale) + Inventory lengkap untuk kedai kopi UMKM.  
Single-file HTML, siap deploy ke Vercel/Netlify.

---

## 🔐 Login Default

| Pengguna | Role | PIN |
|----------|------|-----|
| Budi (Owner) | Owner | `1234` |
| Sari (Kasir) | Kasir | `5678` |

---

## ✨ Fitur Lengkap

### 🛒 Kasir / POS
- Tampilan menu dengan grid, filter per kategori
- Keranjang belanja dengan qty control
- Pembayaran Cash (dengan hitung kembalian) & QRIS
- Cetak struk / nota transaksi
- Menu otomatis nonaktif jika stok habis

### 📊 Dashboard (Owner)
- Omzet, laba, jumlah transaksi hari ini
- Perbandingan vs kemarin (naik/turun %)
- Grafik penjualan 7 hari terakhir
- Menu terlaris hari ini
- Riwayat transaksi terbaru

### 📈 Laporan (Owner)
- **Harian** — pilih tanggal
- **Mingguan** — otomatis hitung per minggu
- **Bulanan** — pilih bulan
- Total omzet, HPP, laba bersih, margin %
- Grafik menu terjual
- Detail transaksi lengkap

### 🍽️ Kelola Menu (Owner)
- Tambah/edit/hapus item menu
- Input harga jual + HPP (modal)
- Kategori & emoji icon
- Indikator margin keuntungan
- Aktif/non-aktif per item

### 📦 Stok Bahan Baku (Owner)
- Manajemen bahan baku dengan satuan (gram, ml, pcs, dll)
- Alert otomatis jika stok di bawah minimum
- Restock bahan langsung dari dashboard
- Status stok: Aman / Kritis / Habis

### 📋 Resep (Owner)
- Hubungkan menu dengan bahan baku
- Atur qty bahan per 1 porsi
- **Stok otomatis berkurang** saat transaksi sesuai resep

### 👥 Pengguna (Owner)
- Tambah/edit/hapus kasir
- Role: Owner (akses penuh) vs Kasir (POS only)
- Login dengan PIN 4 digit

---

## 🚀 Deploy ke Vercel

1. Push repo ke GitHub
2. Login ke [vercel.com](https://vercel.com)
3. New Project → Import repo
4. Deploy ✓

---

## 🛠 Tech Stack
- Pure HTML + CSS + JavaScript (zero dependency)
- Data: localStorage browser
- Font: Sora + Plus Jakarta Sans

---

*Made with ☕ — KedaiKas, Sistem Kasir UMKM Nusantara*
