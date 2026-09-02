# Neovim C# Ortamı

Bu ayar; C# dil sunucusu, otomatik formatlama, hata ayıklama, arama ve Tokyo Night temasını içerir.

## Başlangıç

Bir .NET projesinin kök klasöründe Neovim'i açın:

```sh
nvim .
```

Kaydetme (`:w`) C# dosyalarını CSharpier ile otomatik biçimlendirir.

## Temel Vim

| Kısayol | İşlev |
| --- | --- |
| `i` | Yazma modu |
| `Esc` | Normal moda dön |
| `:w` | Kaydet |
| `:q` | Çık |
| `:wq` | Kaydet ve çık |
| `u` / `Ctrl-r` | Geri al / ileri al |
| `/metin`, `n` | Ara / sonraki sonuç |

## Kod Gezinme

`<leader>` bu ayarda `Space` tuşudur.

| Kısayol | İşlev |
| --- | --- |
| `gd` | Tanıma git |
| `gr` | Referansları göster |
| `K` | Dokümantasyonu aç |
| `Space r n` | Sembolü yeniden adlandır |
| `Space c a` | Kod aksiyonu |
| `Space e` | Hata ayrıntısı |
| `Space x` | Hata listesini panelde aç/kapat |
| `[d` / `]d` | Önceki / sonraki hata |

## Arama

| Kısayol | İşlev |
| --- | --- |
| `Space f f` | Dosya bul |
| `Space f g` | Proje metninde ara |
| `Space f b` | Açık dosyalarda ara |
| `Space f h` | Neovim yardımında ara |
| `Space o` | Dosya gezginini aç |
| `Space n` | Soldaki dosya ağacını aç/kapat |
| `→` (dosya ağacında) | Seçili dosyayı aç; klasörü genişlet |
| `←` (dosya ağacında) | Klasörü daralt; üst klasöre dön |

## Debugger

Önce `dotnet build` çalıştırın. Ardından `F5` ile derlenen `.dll` dosyasını seçin.

| Kısayol | İşlev |
| --- | --- |
| `Space b` | Bulunduğun satırda breakpoint aç/kapat |
| `Space b c` | Tüm breakpoint'leri temizle |
| `F5` | Başlat / devam et |
| `F10` | Step over |
| `F11` | Step into |
| `F12` | Step out |
| `Space d u` | Debug panelini aç/kapat |
| `Space d r` | Debug REPL'i aç |

## Terminal

`Space t t` altta yerleşik terminali açar veya kapatır. `Space t w` `dotnet test --watch` başlatır; `Space r r` test paketini bir kez çalıştırır. Terminal modundan normal moda dönmek için `Ctrl-\\`, sonra `Ctrl-n` kullanın.

## Terminal Araçları

| Komut | İşlev |
| --- | --- |
| `z isim` | Sık kullanılan bir klasöre geçer; ör. `z api` |
| `fd isim` | Dosya adına göre hızlı arama |
| `bat dosya.cs` | Syntax highlighting ile dosya içeriğini gösterir |

## Zsh / Ghostty

| Kısayol | İşlev |
| --- | --- |
| `Ctrl-r` | Altta geçmiş komut aramasını açar; yazdıkça filtreler |
| `Enter` | Açık geçmiş önerisini prompt'a alır; sonraki `Enter` komutu çalıştırır |
| `Option-Delete` | İmlecin solundaki kelimeyi siler |
| `fn-Delete` | İmlecin sağındaki karakteri siler |

## Kısayol Yardımı

Normal modda `Space` tuşuna kısa süre basılı bekleyin: Which-key kullanılabilir devam tuşlarını gösterir.

## Yapılandırma

- `init.lua`: Tüm Neovim ayarları
- `lazy-lock.json`: Eklentilerin sabitlenmiş sürümleri
- `README.md`: Bu rehber
- `bootstrap-macos.sh`: Yeni bir Mac'i aynı ortamla kurar

## Yeni Mac'e Taşıma

Bu klasörü yeni Mac'e taşıyın (Git deposu olarak ya da sıkıştırılmış dosyayla) ve ardından çalıştırın:

```sh
cd ~/.config/nvim
./bootstrap-macos.sh
```

Script Homebrew, .NET SDK, Neovim, Ghostty, font, CSharpier, terminal araçları ve Zsh eklentisini kurar. Var olan yapılandırma dosyalarını `~/.config/neovim-csharp-backup` altında yedekler.

macOS Terminal'in varsayılan Menlo fontuyla uyum için Nerd Font ikonları kapalıdır.
