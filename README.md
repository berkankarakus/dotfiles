# Neovim C# Ortamı

Bu ayar; C# dil sunucusu, otomatik formatlama, hata ayıklama, arama ve Tokyo Night temasını içerir.

## Başlangıç

Bir .NET projesinin kök klasöründe Neovim'i açın:

```sh
nvim .
```

`nvim .`, aynı proje klasöründe en son düzenlediğiniz dosyayı açar.

Kaydetme (`:w`) C# dosyalarını CSharpier ile otomatik biçimlendirir.

Yeni bir `.cs` dosyası oluşturduğunuzda Neovim, bulunduğu `.csproj` ve klasör yolundan file-scoped namespace satırını otomatik ekler.

## C# Şablonları

Yazma modunda `ctor`, `prop`, `propg`, `if`, `for`, `foreach`, `try` veya `cw` yazın; completion menüsünden şablonu `Enter` ile seçin. `Tab` sonraki yer tutucuya, `Shift-Tab` öncekine gider. `ctor`, içinde bulunduğunuz sınıfın adını otomatik kullanır.

Sınıf içinde `Space c a` ayrıca C# dil sunucusunun constructor üretme gibi code action'larını gösterir.

İmleci sınıf, metot veya property bildiriminin üstüne getirin ve `Space c d` ile XML docstring ekleyin. Metot parametreleri için `<param>` satırları da üretilir.

## Temel Vim

| Kısayol | İşlev |
| --- | --- |
| `i` | Yazma modu |
| `Esc` | Normal moda dön |
| `:w` | Kaydet |
| `:q` | Çık |
| `:wq` | Kaydet ve çık |
| `u` / `Ctrl-r` | Geri al / ileri al |
| `Option-Left` / `Option-Right` (yazma modunda) | Önceki / sonraki kelimeye git |
| `Command-Left` / `Command-Right` (yazma modunda) | Satır başına / sonuna git |
| `Left` / `Right` (satır başı/sonunda, yazma modunda) | Önceki satırın sonuna / sonraki satırın başına git |
| `/metin`, `n` | Ara / sonraki sonuç |

## Kod Gezinme

`<leader>` bu ayarda `Space` tuşudur.

| Kısayol | İşlev |
| --- | --- |
| `gd` | Tanıma git |
| `gi` | Implementation'a git |
| `gr` | Referansları göster |
| `K` | Dokümantasyonu aç |
| `Space s` | Metod parametrelerini göster |
| `Space r n` | Sembolü yeniden adlandır |
| `Space c a` | Kod aksiyonu |
| `Space c d` | C# XML docstring ekle |
| `Space e` | Hata ayrıntısı |
| `Space x` | Hata listesini panelde aç/kapat |
| `[d` / `]d` | Önceki / sonraki hata |

Eksik bir import için hatalı sembolün üstünde `Space c a` açıp **Add using...** seçin.

## Arama

| Kısayol | İşlev |
| --- | --- |
| `Space f f` | Dosya bul; son kullanılanlar önce gelir |
| `Space f g` | Proje metninde ara |
| `Space f b` | Açık dosyalarda ara |
| `Space f s` | Açık dosyadaki sınıf/metotları ara |
| `Space f S` | Proje genelindeki sınıf/metotları ara |
| `Space f h` | Neovim yardımında ara |

## Git Değişiklikleri

| Kısayol | İşlev |
| --- | --- |
| `]h` / `[h` | Sonraki / önceki değişen blok |
| `Space g p` | Değişen bloğun önceki hâlini göster |
| `Space g r` | Değişen bloğu geri al |
| `Space g s` | Değişen bloğu stage'e ekle |
| `Space g b` | Satırın Git geçmişini göster |

## Surround

| Kısayol | İşlev |
| --- | --- |
| `sa` sonra çevreleyici | Metni çevrele; ör. `saiw)` kelimeyi paranteze alır |
| `sd` sonra çevreleyici | Çevreleyiciyi sil; ör. `sd)` |
| `sr` eski/yeni çevreleyici | Çevreleyiciyi değiştir; ör. `sr)]` |
| `Space o` | Dosya gezginini aç |
| `Space n` | Soldaki, ikonlu dosya ağacını aç/kapat |
| `→` (dosya ağacında) | Seçili dosyayı aç; klasörü genişlet |
| `←` (dosya ağacında) | Klasörü daralt; üst klasöre dön |
| `W` (dosya ağacında) | Tüm klasörleri kapat |

## Debugger

Önce `dotnet build` çalıştırın. Ardından `F5`, açık C# dosyasının projesindeki Debug `.dll` çıktısını otomatik bulur. Projede `Properties/launchSettings.json` varsa `commandLineArgs`, `workingDirectory` ve environment değerleri de otomatik uygulanır. Bulamazsa yalnızca o zaman DLL yolunu sorar. Apple Silicon macOS'ta yerel ARM netcoredbg ikilisi kullanılır.

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

`Space t t` altta yerleşik terminali açar veya kapatır. `Space t w` `dotnet test --watch` başlatır; `Space r r` test paketini bir kez çalıştırır. Terminaldeyken `Ctrl-\\` terminali gizler ve son editör pencerenize döner. Terminal penceresinde kalıp normal moda geçmek için `Ctrl-\\`, ardından `Ctrl-n` kullanın.

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

Eklentileri güncellemek gerektiğinde `:Lazy sync` çalıştırın. `init.lua` içindeki eklenti ya da ayar değişikliklerinin uygulanması için `:restart` kullanın; Lazy bu dosyanın tekrar source edilmesini desteklemez.

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
