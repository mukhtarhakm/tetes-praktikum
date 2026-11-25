# Tetes Praktikum

Aplikasi Android Flutter untuk mencatat beans, memandu seduh V60, menyimpan jurnal lokal, melihat kurs, mengatur pengingat, menjelajahi roastery dan toko alat kopi, serta meminta saran AI. Proyek ini terpisah dari Tetes tugas teori.

## Yang perlu disiapkan

1. Buat proyek Supabase baru. Aktifkan login email/password. Jika konfirmasi email aktif, pengguna harus membuka tautan konfirmasi sebelum masuk.
2. Salin `config/app.example.json` menjadi `config/app.json`. Isi **Project URL** dan **publishable key** dari Supabase. Jangan isi service role key di sini.
3. Buat OpenAI API key di `platform.openai.com/api-keys`. Salin `supabase/.env.ai.example` menjadi `supabase/.env.ai`, lalu isi `OPENAI_API_KEY`. Berkas ini diabaikan Git. Kunci tetap berada di Supabase, tidak di aplikasi Flutter.
4. Jalankan dari folder proyek:

   ```powershell
   supabase login
   supabase link --project-ref ID_PROYEK_SUPABASE
   supabase db push
   supabase secrets set --env-file supabase/.env.ai
   supabase functions deploy brew-ai
   flutter run --dart-define-from-file=config/app.json
   ```

Untuk membuat APK setelah konfigurasi terisi:

```powershell
flutter build apk --dart-define-from-file=config/app.json
```

## Alur demo

Daftar atau masuk → tambah beans → atur seduh → minta saran AI langsung atau tulis target rasa dan pilih isian yang harus tetap → tinjau rencana AI lengkap sebelum menerapkannya → jalankan sesi seduh → beri skor, pilih rasa, catat timbangan dan drawdown jika ada → simpan → lihat detail jurnal → minta diagnosa AI → cek kurs → lihat toko dan buka Navigasi → atur pengingat seduh.

Saran AI mengutamakan hingga delapan riwayat seduhan skor 5 dari beans yang sama, lalu skor 4 bila masih ada tempat. Setiap seduhan tetap menjadi entri jurnal tersendiri; beberapa resep skor 5 dapat menjadi contoh sekaligus. AI menerima profil beans, resep dan hasil seduhan yang dipilih, serta target rasa dan isian yang dikunci. Rencana yang disarankan mencakup dosis, rasio, suhu, gilingan, jumlah tuangan, durasi, dan air tiap tuangan. Tekan **Terapkan** untuk mengisi formulir; periksa lagi sebelum Mulai seduh. Diagnosa di detail jurnal menerima skor, tag rasa, catatan, urutan tuang, hasil timbangan dan drawdown yang tersedia, serta beberapa seduhan skor 5 dari beans yang sama. Data ini dikirim ke layanan AI hanya saat tombol AI ditekan. Aplikasi yang sudah terpasang tetap didukung oleh fungsi server, tetapi tampilan baru memerlukan APK terbaru.

Data beans dan jurnal disimpan di HP per akun Supabase. **Belum ada sinkronisasi lintas HP**; masuk di HP lain tidak memindahkan jurnal. Login, kurs, peta, dan AI memerlukan internet. Timer, jurnal, dan daftar tempat tetap memakai data lokal. Data tempat saat ini berasal dari `assets/data/stores.json` dan dapat ditambah untuk kota lain; yang tampil hanya roastery dan toko alat kopi. Peta memakai OpenStreetMap. Jarak awal di panel adalah jarak garis lurus. Saat pengguna menekan Lihat rute, koordinat lokasinya dan tempat terpilih dikirim ke server demo `router.project-osrm.org` untuk menampilkan jarak jalan, perkiraan waktu berkendara, dan garis rute. Server demo ini dapat membatasi permintaan atau tidak tersedia; tombol Navigasi tetap membuka rute di aplikasi peta eksternal. Pengingat lokal dapat dijadwalkan sekali, setiap hari, atau setiap minggu dari Profil melalui tab Lainnya; Mulai seduh hanya menjalankan timer di layar. Fungsi AI membatasi 20 panggilan per akun per hari dan API key hanya ada di server. Tetapkan juga batas pemakaian di akun penyedia AI.

Foto profil dipilih dari galeri dan disimpan lokal per akun di HP ini. Foto tidak ikut pindah saat masuk dari HP lain.

## Uji di HP Android

- Daftar, masuk, keluar, lalu masuk lagi. Pastikan jurnal akun sebelumnya tetap ada.
- Matikan internet setelah masuk: tambah biji, seduh, dan buka jurnal. Kurs memakai cache bila pernah diambil.
- Tolak izin lokasi: pin dan daftar tempat tetap muncul tanpa jarak; Lihat rute tidak aktif. Izinkan lokasi: tempat diurutkan menurut jarak. Ketuk pin dan geser panel untuk melihat daftar; tekan Lihat rute dan pastikan jarak jalan, waktu, serta garis rute muncul. Tekan Navigasi dan pastikan rute terbuka di aplikasi peta.
- Di Atur seduh, periksa total air serta rentang waktu, durasi, dan gram tiap tuangan; buka Ubah pada salah satu tahap lalu tekan Batal untuk memastikan layar tetap normal, ubah durasinya dan periksa rentang waktu berikutnya, lalu mulai. Pastikan jam total menghitung maju, warna dan progres lingkaran berganti pada setiap tuangan. Di HP asli, dengarkan satu bunyi dan rasakan satu getar saat pindah tuangan; saat masuk drawdown ada dua nada dan getar yang lebih tegas. Coba tombol suara di atas untuk mematikan keduanya, lalu pastikan tidak ada isyarat ganda pada tahap yang sama. Drawdown menghitung maju sampai Air habis atau Lewati. Sesi tidak meminta izin notifikasi. Setelah selesai, pilih skor dan rasa, isi angka timbangan kumulatif serta drawdown jika ada, lalu simpan. Pastikan detail jurnal menampilkan hasil tersebut. Uji pengingat sekali, harian, dan mingguan dari Profil; tutup aplikasi, lalu cek notifikasi pada waktu yang dipilih. Pastikan Matikan pengingat menghentikan jadwal berulang.
- Coba saran dan diagnosa AI setelah fungsi server terpasang.
