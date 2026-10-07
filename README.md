# Neovim C# Ortamı

Bu ayar; Roslyn tabanlı C# ve Elm dil sunucuları, otomatik formatlama, hata ayıklama, arama ve Tokyo Night temasını içerir.

## Başlangıç

Bir .NET projesinin kök klasöründe Neovim'i açın:

```sh
nvim .
```

`nvim .`, aynı proje klasöründe en son düzenlediğiniz dosyayı açar.

Kaydetme (`:w`) C# dosyalarını Roslyn ile otomatik biçimlendirir. Biçim kuralları, projenin kökündeki `.editorconfig` dosyasından okunur.

Elm projelerinde (`elm.json` bulunan klasörlerde) `elm-language-server` otomatik başlar; kaydetme `elm-format` ile biçimlendirir. Derleme için `elm make`, test için `elm-test` kullanabilirsiniz.

Yeni bir `.cs` dosyası oluşturduğunuzda Neovim, bulunduğu `.csproj` ve klasör yolundan file-scoped namespace satırını otomatik ekler.

## C# Biçimlendirme

CSharpier otomatik formatlamada kullanılmaz; Roslyn `.editorconfig` kurallarını uygular. Örneğin proje köküne aşağıdakine benzer bir dosya koyabilirsiniz:

```ini
[*.cs]
indent_style = space
indent_size = 4
csharp_new_line_before_open_brace = all
csharp_preserve_single_line_blocks = true
csharp_preserve_single_line_statements = true
```

## C# Şablonları

Yazma modunda `ctor`, `prop`, `propg`, `if`, `for`, `foreach`, `dowhile`, `region`, `try` veya `cw` yazın; completion menüsünden şablonu `Enter` ile seçin. `Tab` sonraki yer tutucuya, `Shift-Tab` öncekine gider. `ctor`, içinde bulunduğunuz sınıfın adını otomatik kullanır.

Sınıf içinde `Space c a` ayrıca C# dil sunucusunun constructor üretme gibi code action'larını gösterir. Birkaç statement'ı `V` ile seçip `Space c a` yaptığınızda **Extract method** ile fonksiyona ayırabilirsiniz.

İmleci sınıf, metot veya property bildiriminin üstüne getirin ve `Space c d` ile XML docstring ekleyin. Metot parametreleri için `<param>` satırları da üretilir.

## Temel Vim

| Kısayol | İşlev |
| --- | --- |
| `i` | Yazma modu |
| `Esc` | Normal moda dön |
| `:w` | Kaydet |
| Buffer değiştirince veya Neovim odağı kaybedince | Değişmiş, normal dosyayı otomatik kaydet |
| `:q` | Tüm dosyaları kaydet, sonra çık |
| `:wq` | Kaydet ve çık |
| `u` / `Ctrl-r` | Geri al / ileri al |
| `Shift-↑` / `Shift-↓` | Satırı clipboard’a dokunmadan yukarı / aşağı taşı; yazma modunda da çalışır |
| 80. sütundaki ince çizgi | Önerilen satır uzunluğu rehberi |
| `Option-Left` / `Option-Right` (yazma modunda) | Önceki / sonraki kelimeye git |
| `Command-Left` / `Command-Right` (yazma modunda) | Satır başına / sonuna git |
| `Left` / `Right` (satır başı/sonunda, yazma modunda) | Önceki satırın sonuna / sonraki satırın başına git |
| `Left` / `Right` / `h` / `l` (satır başı/sonunda, normal modda) | Önceki satırın sonuna / sonraki satırın başına git |
| `za` (blok veya `#region` üstünde) | Katlamayı aç/kapat |
| `zM` / `zR` | Tüm katlamaları kapat / aç |
| `/metin`, `n` | Ara / sonraki sonuç |

## Kod Gezinme

`<leader>` bu ayarda `Space` tuşudur.

| Kısayol | İşlev |
| --- | --- |
| `gd` | Tanıma git |
| `gi` | Implementation'a git |
| `gr` | Referansları göster |
| Değişken/metot üzerinde kısa süre bekle | Açık dosyadaki kullanımlarını vurgula |
| SQL'de bir identifier üzerinde kısa süre bekle | Aynı identifier'ın diğer geçişlerini vurgula (harf duyarsız) |
| `K` | Dokümantasyonu aç |
| `Space s` | Metod parametrelerini göster |
| `Space r n` | Sembolü yeniden adlandır |
| `Space c a` | Kod aksiyonu |
| `Space c d` | C# XML docstring ekle |
| `Space c f` | Dosyayı; Visual modda yalnızca seçili kodu biçimlendir |
| `Space e` | Hata ayrıntısı |
| `Space x` | Hata listesini panelde aç/kapat |
| `[d` / `]d` | Önceki / sonraki hata |

Eksik bir import için hatalı sembolün üstünde `Space c a` açıp **Add using...** seçin.

## Tree-sitter Text Objects

C# ve T-SQL dosyalarında sözdizimine göre seçim yapmak için aşağıdaki text object'ler Visual (`v`) ve operator-pending modunda çalışır; örneğin `vab` bir block'u seçer, `daf` ise bir metodu siler.

| Kısayol | İşlev |
| --- | --- |
| `vab` / `vib` | Block'un tamamını / içini ( `{}` hariç) seç |
| `vaf` / `vif` | Metot veya function'ın tamamını / içini ( `{}` hariç) seç |
| `val` / `vil` | `for`, `foreach`, `while` veya `do` loop'un tamamını / içini ( `{}` hariç) seç |
| `vaC` / `viC` | `if` veya `switch` conditional'ının tamamını / içini ( `{}` hariç) seç |
| `vac` / `vic` | Class, struct, record, interface veya enum'un tamamını / içini seç |
| `vaa` / `via` | Parametre ya da argument'ın tamamını / içini seç |
| `vaq` | T-SQL query'sinin tamamını seç |
| `vaS` | T-SQL statement'ının tamamını seç |
| `]f` / `[f` | Sonraki / önceki method, function, procedure veya trigger başlangıcı |
| `]F` / `[F` | Sonraki / önceki method, function, procedure veya trigger sonu |
| `]c` / `[c` | Sonraki / önceki conditional başlangıcı |
| `]C` / `[C` | Sonraki / önceki conditional sonu |
| `]r` / `[r` | Sonraki T-SQL query / iç query'den parent query veya statement'a çık |
| `]k` / `[k` | T-SQL'de sonraki / önceki clause (`SELECT`, `FROM`, `JOIN`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `OFFSET/FETCH`; ayrıca `UPDATE`/`DELETE` ve `SET`); C#'ta sonraki / önceki class, method, field veya statement (block'larda durmadan içeri girer) |
| `]s` / `[s` | Sonraki / önceki T-SQL statement |
| `]S` / `[S` | Sonraki / önceki yazım hatası (spellcheck açıkken) |
| `]K` / `[K` | Sonraki / önceki C# `case` veya `default` bölümü |

T-SQL'de `vaf` / `vif` stored procedure, function veya trigger'ı; `vab` / `vib` ise `BEGIN` / `END` block'unu seçer. İç seçimler `BEGIN` ve `END` anahtar sözcüklerini kapsamaz.

## Arama

| Kısayol | İşlev |
| --- | --- |
| `Space f f` | Mevcut projedeki tüm dosyaları bul; sık ve yakın zamanda kullanılanlar önce gelir |
| `Space f g` | Proje metninde, büyük/küçük harf duyarsız ara |
| `Space f G` | Kaynak ve proje dosyalarında fuzzy ara; karakterler sıralı geçsin yeter |
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
| `ds` sonra çevreleyici | Çevreleyiciyi sil; ör. `ds}` çok satırlı bloğu da bir seviye geri alır |
| `sr` eski/yeni çevreleyici | Çevreleyiciyi değiştir; ör. `sr)]` |
| `Space o` | Dosya gezginini aç |
| `Space n` | Soldaki, ikonlu dosya ağacını aç/kapat |
| `→` (dosya ağacında) | Seçili dosyayı aç; klasörü genişlet |
| `←` (dosya ağacında) | Klasörü daralt; üst klasöre dön |
| `Tab` (dosya ağacında) | Seçili dosyayı geçici preview olarak aç; odak ağaçta kalır |
| `W` (dosya ağacında) | Tüm klasörleri kapat |

## Debugger

Önce `dotnet build` çalıştırın. Ardından `F5`, açık dosya bir class library içindeyse çözümdeki çalıştırılabilir (`OutputType=Exe`, Web veya Worker SDK) projeyi bulup onun Debug `.dll` çıktısını başlatır. Projede `Properties/launchSettings.json` varsa `commandLineArgs`, `workingDirectory` ve environment değerleri de otomatik uygulanır. Web projelerinde `applicationUrl` uygulanır; `launchBrowser` açıksa Swagger adresi açılır. Breakpoint'ler proje kapatılıp açıldığında korunur. Breakpoint'e ulaşıldığında macOS bildirimi gelir; bildirime tıklamak Neovim'in çalıştığı terminali öne getirir. Bulamazsa yalnızca o zaman DLL yolunu sorar. Apple Silicon macOS'ta yerel ARM netcoredbg ikilisi kullanılır.

Terminaldeki `dotnet run`, aksi belirtilmedikçe Release yapılandırmasını kullanır. `Microsoft.NET.Sdk.Web` projelerinde `launchSettings.json` içinde `launchBrowser: true` ve `applicationUrl` tanımlıysa uygulama hazır olduğunda Swagger adresi tarayıcıda açılır. `--configuration Debug` veya `--no-launch-profile` gibi açık seçenekler korunur; Worker ve class library projeleri tarayıcı açmaz.

Terminalde `git diff`, whitespace farklarını göstermez. Değişiklik yalnızca whitespace ise bunun yerine kısa bir uyarı yazar; ham görünümü gerektiğinde `command git diff` ile alabilirsiniz.

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

`Space t t` altta yerleşik terminali açar veya kapatır. `Space t w` `dotnet test --watch` başlatır; `Space r r` test paketini bir kez çalıştırır. Terminaldeyken `Ctrl-\\` terminali anında gizler ve son editör pencerenize döner.

## Terminal Araçları

| Komut | İşlev |
| --- | --- |
| `z isim` | Sık kullanılan bir klasöre geçer; ör. `z api` |
| `fd isim` | Dosya adına göre hızlı arama |
| `bat dosya.cs` | Syntax highlighting ile dosya içeriğini gösterir |
| `fossil status`, `changes`, `addremove`, `extras`, `timeline`, `branch list`, `tag list`, `info`, `annotate` | Durum, geçmiş ve metadata çıktısını renkli gösterir |

## Zsh / Ghostty

| Kısayol | İşlev |
| --- | --- |
| `Ctrl-r` | Altta geçmiş komut aramasını açar; yazdıkça filtreler |
| `Enter` | Açık geçmiş önerisini prompt'a alır; sonraki `Enter` komutu çalıştırır |
| `Ctrl-g` | Silik geçmiş önerisini kapatır; yazılan komutu korur |
| `Option-Delete` | İmlecin sağındaki kelimeyi siler |

## Kısayol Yardımı

Normal modda `Space` tuşuna kısa süre basılı bekleyin: Which-key kullanılabilir devam tuşlarını gösterir.

Eklentileri güncellemek gerektiğinde `:Lazy sync` çalıştırın. `init.lua` içindeki eklenti ya da ayar değişikliklerinin uygulanması için `:restart` kullanın; Lazy bu dosyanın tekrar source edilmesini desteklemez.

Eklenti güncellemesinden sonra tüm eklenti yapılandırmalarının yüklenmesini, önemli kısayolları ve C#/SQL dosya türü ayarlarını doğrulamak için Neovim config klasöründe `bash tests/run.sh` çalıştırın. Test, kayıtlı tüm Lazy eklentilerini headless ortamda yükler; bir eklentinin API değişikliği yapılandırma hatasına yol açarsa başarısız olur.

## Yapılandırma

- `init.lua`: Tüm Neovim ayarları
- `lazy-lock.json`: Eklentilerin sabitlenmiş sürümleri
- `README.md`: Bu rehber
- `bootstrap-macos.sh`: Yeni bir Mac'i aynı ortamla kurar
- `bootstrap-macos-csharp.sh`: Fossil ve Elm araçlarını kurmadan C#/Neovim ortamını kurar

## Yeni Mac'e Taşıma

Bu klasörü yeni Mac'e taşıyın (Git deposu olarak ya da sıkıştırılmış dosyayla) ve ardından çalıştırın:

```sh
cd ~/.config/nvim
./bootstrap-macos.sh
```

Script Homebrew, .NET SDK, Roslyn language server, Neovim, Ghostty, font, Fossil, terminal araçları, debugger ve Zsh eklentisini kurar. Neovim'in `lua`, `after` ve `templates` dosyaları dahil tüm yapılandırması taşınır; var olan dosyalar `~/.config/neovim-csharp-backup` altında yedeklenir.

Roslyn language server'ın stable paketi bulunmadığında bootstrap, NuGet'teki en güncel prerelease sürümünü kurar; sonraki çalıştırmalarda aracı mevcut en güncel sürüme yükseltir.

Fossil ve Elm gerekmeyen bir Mac'te bunun yerine şunu çalıştırın:

```sh
./bootstrap-macos-csharp.sh
```

Bu varyant Elm, `elm-language-server`, Tree-sitter Elm parserı ve Fossil'i kurmaz; C#, debugger, Ghostty, Zsh araçları ve tüm Neovim ayarları korunur.

macOS Terminal'in varsayılan Menlo fontuyla uyum için Nerd Font ikonları kapalıdır.
