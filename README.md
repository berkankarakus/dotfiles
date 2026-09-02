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
| `[d` / `]d` | Önceki / sonraki hata |

## Arama

| Kısayol | İşlev |
| --- | --- |
| `Space f f` | Dosya bul |
| `Space f g` | Proje metninde ara |
| `Space f b` | Açık dosyalarda ara |
| `Space f h` | Neovim yardımında ara |

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

`Space t t` altta yerleşik terminali açar veya kapatır. Terminal modundan normal moda dönmek için `Ctrl-\\`, sonra `Ctrl-n` kullanın.

## Yapılandırma

- `init.lua`: Tüm Neovim ayarları
- `lazy-lock.json`: Eklentilerin sabitlenmiş sürümleri
- `README.md`: Bu rehber

macOS Terminal'in varsayılan Menlo fontuyla uyum için Nerd Font ikonları kapalıdır.
