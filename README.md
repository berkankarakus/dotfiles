# Neovim C# Ortamı

Bu ayar; Roslyn tabanlı C# ve Elm dil sunucuları, otomatik formatlama, hata ayıklama, arama ve Tokyo Night temasını içerir.

## Başlangıç

Bir .NET projesinin kök klasöründe Neovim'i açın:

```sh
nvim .
```

`nvim .`, aynı proje klasöründe en son düzenlediğiniz dosyayı açar.

Kaydetme dosyayı biçimlendirmez. Biçimlendirmek için `Space c f` kullanın (Visual modda yalnızca seçili kısım); C# dosyalarında Roslyn kullanılır ve biçim kuralları projenin kökündeki `.editorconfig` dosyasından okunur.

Elm projelerinde (`elm.json` bulunan klasörlerde) `elm-language-server` otomatik başlar; `Space c f` `elm-format` ile biçimlendirir. Derleme için `elm make`, test için `elm-test` kullanabilirsiniz.

Yeni bir `.cs` dosyası oluşturduğunuzda Neovim, bulunduğu `.csproj` ve klasör yolundan file-scoped namespace satırını otomatik ekler.

## CI/CD

`.github/workflows/neovim.yml`, `main` branch'ine push ve pull request'lerde macOS üzerinde pinned Lazy eklentilerini, Tree-sitter parser'larını ve `bash tests/run.sh` testlerini çalıştırır.

## C# Biçimlendirme

CSharpier kullanılmaz; `Space c f` ile Roslyn `.editorconfig` kurallarını uygular. Örneğin proje köküne aşağıdakine benzer bir dosya koyabilirsiniz:

```ini
[*.cs]
indent_style = space
indent_size = 4
csharp_new_line_before_open_brace = all
csharp_preserve_single_line_blocks = true
csharp_preserve_single_line_statements = true
```

## C# Şablonları

Yazma modunda `ctor`, `prop`, `propg`, `if`, `for`, `foreach`, `dowhile`, `?:` (`condition ? trueValue : falseValue`), `lst`, `hset`, `arr`, `dict`, `queue`, `stack` (tipi solda bir kez yazılan koleksiyon bildirimi; `lst`, `hset`, `arr` için `= [|];`, `queue` ve `stack` için `= new([|]);` (`Add` metotları olmadığı için elemanlar kurucuya girer), `dict` için `= new() { [anahtar] = değer };`; C# 12+), `swe` (switch expression: sonucu yazıp `Tab`'a basınca yeni kol eklenir; dokunmadığınız boş kolda `Tab` onu geri siler ve `_ =>` varsayılanına geçer), `region`, `try` veya `cw` yazın; completion menüsünden şablonu `Enter` ile seçin. `Tab` sonraki yer tutucuya, `Shift-Tab` öncekine gider. `ctor`, içinde bulunduğunuz sınıfın adını otomatik kullanır.

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
| 120. sütundaki ince çizgi | Önerilen satır uzunluğu rehberi |
| `Option-Left` / `Option-Right` (yazma modunda) | Önceki / sonraki kelimeye git |
| `Option-i` (C# yazma modunda) | `new List<int>()` içindeki `()` yerine `{ | }` koleksiyon başlatıcısı koyar; `new int[3]` sonuna da ekler; hedef tipli `new()` için `new() { | }` yapar |
| Tamamlama sonrası (C#) | `HashSet<int\|>`, `List<Foo\|>`, `typeof(Foo\|)`, `sizeof`, `default` ve `nameof(...)` içinde öneriyi onaylayınca imleç kapanış `>` / `)` sonrasına geçer; satır `>` ile bitiyorsa araya bir boşluk eklenir (`List<int> |`, değişken adını yazmak için), `(` ya da `;` geliyorsa bitişik kalır (tek tip argümanlı jenerikler: `List`, `HashSet`, `Task`, `IEnumerable` vb.; `Dictionary<` gibi çok argümanlılarda virgül için yerinde kalır). `nameof` içinde metot `()` almaz |
| `Option-u` (C# yazma modunda) | `List<int> l = new List<int>()` ya da `new()` ifadesini `[|]` koleksiyon ifadesine çevirir (C# 12+); `List<int> m` gibi başlatıcısız bir bildirimin sonunda ` = [|]` ekler (tip yazılı ve koleksiyon olmalı: `List`, `HashSet`, `int[]`, `IEnumerable` vb.). Hedef tip bilinmeli: `var x = new List<int>()`, argümanlı kurucu ve başlatıcılı ifadelere dokunmaz |
| `Option-Enter` (C# yazma modunda) | İfadeyi bitirir: imleç `)` / `]` içinde olsa bile onların dışına atlar ve eksik `;`'yi ekler. Sonraki satır ne ile başlarsa başlasın çalışır; alan, property başlatıcısı, `=>` gövdesi, dosya üstü ifadeler ve `using` dahildir. `if (x)` başlığı, kapanmamış parantez, zincirin ortasındaki satır ve lambda gövdesi gibi belirsiz satırlara dokunmaz |
| `Command-Left` / `Command-Right` (yazma modunda) | Satır başına / sonuna git |
| `Left` / `Right` (satır başı/sonunda, yazma modunda) | Önceki satırın sonuna / sonraki satırın başına git |
| `Left` / `Right` / `h` / `l` (satır başı/sonunda, normal modda) | Önceki satırın sonuna / sonraki satırın başına git |
| `za` (blok veya `#region` üstünde) | Katlamayı aç/kapat |
| `zM` / `zR` | Tree-sitter katlamalarını tümüyle kapat / aç |
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
| `Option-s` / `Option-Shift-s` | Açık imza yardımında sonraki / önceki overload'a geç |
| `Space r n` | Sembolü yeniden adlandır |
| `Space c a` | Kod aksiyonu |
| `Space c d` | C# XML docstring ekle |
| `Space c f` | Dosyayı; Visual modda yalnızca seçili kodu biçimlendir (C#: Roslyn, Elm: `elm-format`, JSON: `jq`) |
| `Space e` | Hata ayrıntısı |
| `Space x` | Hata listesini panelde aç/kapat |
| `[d` / `]d` | Önceki / sonraki hata |

Eksik bir import için hatalı sembolün üstünde `Space c a` açıp **Add using...** seçin.

## sqldeps ile T-SQL Desteği

`.sql` tamponlarında `sqldeps lsp`, ScriptDom ile ayrıştırma, tanılar, completion, hover ve gezinmeyi sağlar.
`gd`, `gr` ve `K` sırasıyla tanıma gitme, başvuruları bulma ve hover içindir; `Space d s` belge, `Space w s`
çalışma alanı sembollerini açar. `Space c a`, sqldeps lint tanıları için quick fix'leri açar. Rename ve
formatlama özellikle yapılandırılmaz, çünkü sqldeps bunları desteklemez.

Tree-sitter MSSQL parser'ı bunun yanında kalır: renklendirme, folding, text object ve clause hareketleri için
kullanılır. Bir SQL projesini önce `sqldeps index .` ile indekslemek komut satırı sorguları ve C# → SQL
gezinmesi için hâlâ gereklidir. `:SqlDef`, `:SqlRefs` ve `:SqlColumns` bu ikinci kullanım için SQLite indeksini
quickfix listesinde açar; adı komuta doğrudan da verebilirsiniz (`:SqlDef dbo.UpdatePrices`).
Bir C# tamponunda prosedür adının üstündeyken `Space c s`, tek bir tanım bulunursa onu doğrudan açar;
birden fazla tanım varsa seçim için quickfix listesi açılır. Kaydedilmemiş C# değişikliği varsa mevcut
tamponu korumak için tanım sağ bölmede açılır.

Varsayılan indeks, Neovim'in çalışma klasörü için `~/.local/share/sqldeps/<klasör>.sqlite` yolunda aranır.
Farklı bir indeks veya SQL kökü için Neovim'de şunları ayarlayabilirsiniz:

```lua
vim.g.sqldeps_database = "/mutlak/yol/deps.sqlite"
vim.g.sqldeps_root = "/mutlak/yol/sql-kaynaklari"
```

## Tree-sitter Text Objects

C#, T-SQL ve JSON dosyalarında sözdizimine göre seçim yapmak için aşağıdaki text object'ler Visual (`v`) ve operator-pending modunda çalışır; örneğin `vab` bir block'u seçer, `daf` ise bir metodu siler.

| Kısayol | İşlev |
| --- | --- |
| `vab` / `vib` | Block'un tamamını / içini ( `{}` hariç) seç; JSON'da nesne veya dizi ( `{}` / `[]` hariç) |
| `vaf` / `vif` | Metot veya function'ın tamamını / içini ( `{}` hariç) seç |
| `val` / `vil` | `for`, `foreach`, `while` veya `do` loop'un tamamını / içini ( `{}` hariç) seç |
| `vaC` / `viC` | `if` veya `switch` conditional'ının tamamını / içini ( `{}` hariç) seç |
| `vac` / `vic` | Class, struct, record, interface veya enum'un tamamını / içini seç |
| `vaa` / `via` | Parametre ya da argument'ın tamamını / içini seç; JSON'da anahtar-değer çifti veya dizi öğesi (`vaa` virgülü de alır, sondaki öğede öncekini) |
| `vaq` | T-SQL query'sinin tamamını seç |
| `vaS` | T-SQL statement'ının tamamını seç |
| `]f` / `[f` | Sonraki / önceki method, function, procedure veya trigger başlangıcı |
| `]F` / `[F` | Sonraki / önceki method, function, procedure veya trigger sonu |
| `]a` / `[a` | Sonraki / önceki method argümanı veya parametresi |
| `]c` / `[c` | Sonraki / önceki conditional başlangıcı |
| `]C` / `[C` | Sonraki / önceki conditional sonu |
| `]r` / `[r` | Sonraki T-SQL query / iç query'den parent query veya statement'a çık; JSON'da sonraki / önceki nesne veya dizi (`]r` ve `[r` birbirinin aynasıdır, uçlarda sarar) |
| `]k` / `[k` | T-SQL'de sonraki / önceki clause (`SELECT`, `FROM`, `JOIN`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `OFFSET/FETCH`; ayrıca `UPDATE`/`DELETE` ve `SET`); C#'ta sonraki / önceki class, method, field veya statement (block'larda durmadan içeri girer); JSON'da sonraki / önceki anahtar-değer çifti veya dizi öğesi |
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

## Surround

| Kısayol | İşlev |
| --- | --- |
| `sa` sonra çevreleyici | Metni çevrele; ör. `saiw)` kelimeyi paranteze alır |
| `ds` sonra çevreleyici | Çevreleyiciyi sil; ör. `ds}` çok satırlı bloğu da bir seviye geri alır; ardından yalnızca etkilenen satırlar biçimlendirilir |
| `sr` eski/yeni çevreleyici | Çevreleyiciyi değiştir; ör. `sr)]` |
| `Space o` | Dosya gezginini aç |
| `Space n` | Soldaki, ikonlu dosya ağacını aç/kapat |
| `→` (dosya ağacında) | Seçili dosyayı aç; klasörü genişlet |
| `←` (dosya ağacında) | Klasörü daralt; üst klasöre dön |
| `Tab` (dosya ağacında) | Seçili dosyayı geçici preview olarak aç; odak ağaçta kalır |
| `W` (dosya ağacında) | Tüm klasörleri kapat |

## Debugger

Önce `dotnet build` çalıştırın. Ardından `F5`, açık dosya bir class library içindeyse çözümdeki çalıştırılabilir (`OutputType=Exe`, Web veya Worker SDK) projeyi bulup onun Debug `.dll` çıktısını başlatır. Projede `Properties/launchSettings.json` varsa `commandLineArgs`, `workingDirectory` ve environment değerleri de otomatik uygulanır. Web projelerinde `applicationUrl` uygulanır; `launchBrowser` açıksa Swagger adresi açılır. Breakpoint'ler proje kapatılıp açıldığında korunur. Breakpoint'e ulaşıldığında macOS bildirimi gelir; bildirime tıklamak Neovim'in çalıştığı terminali öne getirir. Bulamazsa yalnızca o zaman DLL yolunu sorar. Apple Silicon macOS'ta yerel ARM netcoredbg ikilisi kullanılır.

### .NET Framework projelerini hata ayıklama (Mono)

`F5`, projeye bakarak hata ayıklayıcıyı seçer: `net4x` hedefli (`net48`, `net472` vb.) ya da eski tarz `TargetFrameworkVersion v4.x` projeleri Mono'nun hata ayıklayıcısıyla (Microsoft'un `mono-debug` adaptörü), diğerleri `netcoredbg` ile başlar. Çalıştırılacak dosya `bin/Debug` altındaki en yeni `<AssemblyName>.exe`'dir; önce projeyi derleyin (`Space r b`, eski tarz projede terminalden `msbuild`). Çıktı Neovim içindeki konsolda görünür.

Gerekenler: Mono (`brew install mono`) ve `mono-debug.exe`. İkisi de `./bootstrap-macos.sh --with-mono` ile kurulur; elle kurmak için adaptör Microsoft'un hazır paketinden (Open VSX'teki `ms-vscode.mono-debug` 0.16.3) çıkarılıp `~/.local/share/nvim/mono-debug/` altına konur (adres `NEO_MONO_DEBUG` ortam değişkeniyle değiştirilebilir). Kaynaktan derlemek (`vscode-mono-debug` deposu) macOS'ta `dotnet build` ile çalışmaz: alt projeler eski tarz ve NuGet paketlerini çözemez. Paketin yayınlanan SHA-256 özeti kontrol edilir:

```sh
d=$(mktemp -d)
curl -fsSL -o "$d/mono-debug.vsix" https://open-vsx.org/api/ms-vscode/mono-debug/0.16.3/file/ms-vscode.mono-debug-0.16.3.vsix
echo "a9a6b460583f81f96077bdec636671058ca89fd4b4b07fec3c77a2bcf60deace  $d/mono-debug.vsix" | shasum -a 256 -c -
unzip -q "$d/mono-debug.vsix" 'extension/bin/Release/*' -d "$d/out"
mkdir -p ~/.local/share/nvim/mono-debug
cp -R "$d/out/extension/bin/Release/." ~/.local/share/nvim/mono-debug/
ls ~/.local/share/nvim/mono-debug/mono-debug.exe
```

Adaptör yoksa `F5` bir hata mesajıyla durur. Ayrıntı: `lua/neo/dotnet_debug.lua` (proje tanıma, `.exe` bulma) ve `lua/neo/plugins/debug.lua`.


Terminaldeki `dotnet run`, aksi belirtilmedikçe Release yapılandırmasını kullanır. `Microsoft.NET.Sdk.Web` projelerinde `launchSettings.json` içinde `launchBrowser: true` ve `applicationUrl` tanımlıysa uygulama hazır olduğunda Swagger adresi tarayıcıda açılır. `--configuration Debug` veya `--no-launch-profile` gibi açık seçenekler korunur; Worker ve class library projeleri tarayıcı açmaz.

Terminalde `git diff`, whitespace farklarını göstermez. Değişiklik yalnızca whitespace ise bunun yerine kısa bir uyarı yazar; ham görünümü gerektiğinde `command git diff` ile alabilirsiniz.

| Kısayol | İşlev |
| --- | --- |
| `Space b` | Bulunduğun satırda breakpoint aç/kapat |
| `F5` | Başlat / devam et |
| `F10` | Step over |
| `F11` | Step into |
| `F12` | Step out |
| `Space d u` | Debug panelini aç/kapat |
| `Space d c` | Tüm breakpoint'leri temizle |
| `Space d r` | Debug REPL'i aç |

## Terminal

`Space t t` altta yerleşik terminali açar veya kapatır. `Space t w` `dotnet test --watch` başlatır; `Space r r` test paketini bir kez çalıştırır; `Space r t` imlecin bulunduğu test metodunu (metodun dışında ama sınıfın içindeyse sınıfı) yalnızca kendisini çalıştıracak şekilde `dotnet test --filter` ile başlatır. Metot adı Tree-sitter ile bulunur, bu yüzden xUnit, NUnit ve MSTest ile aynı çalışır; `Adds` çalıştırılırken `Adds2` ya da başka bir sınıftaki `Adds` çalışmaz, `Theory` satırlarının hepsi çalışır. Terminaldeyken `Ctrl-\\` terminali anında gizler ve son editör pencerenize döner.

`Space r b` (veya `:DotnetBuild`) açık dosyanın üstündeki çözümü (`.sln`/`.slnx`, yoksa `.csproj`) editörü bloklamadan derler. Hatalar ve uyarılar quickfix listesine düşer; hata varsa liste açılır, `:cnext` / `:cprev` ile açık olmayan dosyalardaki hatalara da gidebilirsiniz. Hataları düzeltince quickfix penceresindeyken tekrar `Space r b` basmanız yeterli; son derlenen hedef kullanılır.

### Sistem kaynak monitorü

Bootstrap, macOS'ta `com.neovim.resource-watch` LaunchAgent'ını kurar. Monitor her 15 saniyede bir tüm süreçleri ve sistem belleği baskısını kontrol eder; bir süreç üç ölçüm boyunca `%80` CPU'yu aşarsa veya boş bellek `%10` altına inerse tek bir macOS bildirimi gönderir. Süreçleri durdurmaz ve hiçbir veriyi dışarı göndermez.

Eşikler ortam değişkenleriyle değiştirilebilir: `NEO_RESOURCE_INTERVAL`, `NEO_RESOURCE_CPU_THRESHOLD`, `NEO_RESOURCE_MEMORY_FREE_THRESHOLD` ve `NEO_RESOURCE_SAMPLES_REQUIRED`. Monitorü kapatmak için `launchctl bootout gui/$UID/com.neovim.resource-watch`, tekrar açmak için bootstrap'ı yeniden çalıştırın.

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
| `Enter` | Yazılan komutu çalıştırır; silik geçmiş önerisini kabul etmez |
| `Ctrl-g` | Silik geçmiş önerisini prompt'a alır (kabul eder); komutu çalıştırmaz |
| `Option-Delete` | İmlecin sağındaki kelimeyi siler |

## Kısayol Yardımı

Normal modda `Space` tuşuna kısa süre basılı bekleyin: Which-key kullanılabilir devam tuşlarını gösterir.

`Space Space`, arama vurgusunu ve komut satırında kalan mesajı hemen temizler. Hata vermeyen bir `:` komutundan 3 saniye sonra komut satırı kendiliğinden temizlenir; hata mesajları ekranda kalır. `Ctrl-l` pencere gezintisine ayrıldığı için olağan yeniden çizim tuşu kullanılamaz.

Eklentileri güncellemek gerektiğinde `:Lazy sync` çalıştırın. `init.lua` içindeki eklenti ya da ayar değişikliklerinin uygulanması için `:restart` kullanın; Lazy bu dosyanın tekrar source edilmesini desteklemez.

Eklenti güncellemesinden sonra tüm eklenti yapılandırmalarının yüklenmesini, önemli kısayolları ve C#/SQL dosya türü ayarlarını doğrulamak için Neovim config klasöründe `bash tests/run.sh` çalıştırın. Test, kayıtlı tüm Lazy eklentilerini headless ortamda yükler; bir eklentinin API değişikliği yapılandırma hatasına yol açarsa başarısız olur.

## Yapılandırma

- `init.lua`: Giriş noktası; `lua/neo` modüllerini sırayla yükler
- `lua/neo/plugins.lua`: lazy.nvim'i kurar ve `lua/neo/plugins/*.lua` modüllerindeki eklenti tanımlarını birleştirir
- `lua/neo/plugins/`: Eklenti tanımları, konuya göre ayrılmıştır: `ui`, `editing`, `navigation`, `treesitter`, `lsp`, `completion`, `debug`
- `lua/neo/textobjects.lua`: Tree-sitter textobject seçimi ve yapısal hareketler (`]f`, `]a`, `]k`, `]s`, ...)
- `lua/neo/dotnet_debug.lua`: Debugger için .NET proje keşfi ve `launchSettings.json` okuma
- `lua/neo/call_parens.lua`: C# tamamlamadan sonra `()` ekleme; imleç konumu ve ilk argüman şablonu (`''`, `x => `), `new int[]` ve generic `<>` tipe göre belirlenir. Ayrıca yazma modu tuşları: `to_initializer` (`Option-i`), `to_collection_expression` (`Option-u`), `finish_statement` (`Option-Enter`)
- `lua/neo/lsp.lua`: Roslyn ve Elm dil sunucusu ayarları, LSP tuşları (`nvim-lspconfig` kullanılmaz; Elm sunucusu tanımı burada)
- `lua/neo/snippets.lua`: `swe` switch expression snippet'i ve `Tab` ile kol ekleme/silme mantığı
- `lua/neo/dotnet_build.lua`: `dotnet build` hatalarını quickfix'e alır (`Space r b`)
- `lua/neo/dotnet_test.lua`: İmlecin altındaki testi veya sınıfı çalıştırır (`Space r t`)
- `lua/neo/doctor.lua`: `:NeoDoctor` sağlık raporu
- `lazy-lock.json`: Eklentilerin sabitlenmiş sürümleri
- `README.md`: Bu rehber
- `bootstrap-macos.sh`: Yeni bir Mac'i aynı ortamla kurar
- `bootstrap-macos-csharp.sh`: `bootstrap-macos.sh --no-elm` için kısa sarmalayıcı (Fossil ve Elm araçları kurulmaz)
- `scripts/resource-watch.sh`: Sistem genelinde CPU/bellek alarmı
- `templates/com.neovim.resource-watch.plist`: Monitor LaunchAgent şablonu

## Makine Denetimi (`:NeoDoctor`)

`:NeoDoctor`, bu config'in dayandığı her şeyi tek raporda listeler ve bu makinenin beklenenle uyuşup uyuşmadığını gösterir (`q` kapatır). Her satır `ok`, `WARN`, `FAIL` veya (Elm gibi isteğe bağlı kurulmayan şeyler için) `info` olarak işaretlenir. Bölümler:

- **Environment:** Neovim sürümü ve konumu, işlemci mimarisi, macOS sürümü, kabuk, Ghostty sürümü.
- **Deployed files:** Bootstrap'ın repodaki şablonlardan dağıttığı dosyalar (`~/.config/zsh/neovim-csharp.zsh`, `~/.config/ghostty/config`) şablonla aynı mı; farklıysa ilk farklı satırı iki sürümüyle gösterir. Ayrıca `~/.zshrc` zsh dosyasını `source` ediyor mu ve `zsh-autosuggestions` kurulu mu. `~/.claude/CLAUDE.md`'nin (ve `~/.codex` varsa `~/.codex/AGENTS.md`'nin) depodaki `templates/*-global.md` dosyasına giden bir sembolik bağlantı olup olmadığına da bakar; bağlantı sıradan bir dosyaya dönmüşse ya da kopmuşsa uyarır.
- **Ghostty:** `ghostty +show-config` çıktısına göre şablondaki her ayarın ve tuş bağının gerçekten uygulandığı (varsayılan değerler dahil) ve `~/Library/Application Support/com.mitchellh.ghostty/config` gibi, ana config'i geçersiz kılabilecek ikinci bir config olup olmadığı.
- **Tools:** Roslyn'in sabitlenen sürümle kurulu sürümü ve `dotnet`, `git`, `rg`, `fd`, `tree-sitter`, `jq`, `fzf`, `zoxide`, `bat`, `terminal-notifier` ile Elm araçlarının (`node`, `elm`, `elm-format`, `elm-language-server`, `elm-test`, `fossil`) konumu ve sürümü.
- **Plugins:** Eklentilerin `lazy-lock.json` ile aynı commit'te olup olmadığı. `:NeoDoctor!` her eklentiyi commit'iyle tek tek listeler.
- **Parsers and debugger:** Tree-sitter parser'ları ve debugger.

Dosya sapması, bir makinede sessizce farklı davranışa yol açar: örneğin `Ctrl-g` ayarı yalnızca dağıtılan dosyada değiştirilirse repodaki şablon eski kalır ve başka bir Mac eskisi gibi çalışır. İki Mac farklı davrandığında ikisinde de çalıştırıp çıktıları karşılaştırın.

## Yeni Mac'e Taşıma

Bu klasörü yeni Mac'e taşıyın (Git deposu olarak ya da sıkıştırılmış dosyayla) ve ardından çalıştırın:

```sh
cd ~/.config/nvim
./bootstrap-macos.sh
```

Script Homebrew, .NET SDK, Roslyn language server, sqldeps LSP, Neovim, Ghostty, font, Fossil, terminal araçları, debugger ve Zsh eklentisini kurar. Neovim'in `lua`, `after` ve `templates` dosyaları dahil tüm yapılandırması taşınır; var olan dosyalar `~/.config/neovim-csharp-backup` altında yedeklenir. sqldeps kaynaklarını `~/Projects/sqldeps` altında klonlar ve `install.sh` ile `sqldeps lsp` komutunu kurar; mevcut bir sqldeps klasörünü değiştirmez.

Bootstrap eklentileri `lazy-lock.json` içindeki commit'lere sabitler (`Lazy! install`, ardından `Lazy! restore`); böylece iki Mac aynı eklenti sürümlerini kullanır. Roslyn language server de `bootstrap-macos.sh` içindeki `ROSLYN_VERSION` sürümüne sabitlenir; sürüm yükseltmek için bu değeri bilerek değiştirin. Kurulum sonunda Roslyn, debugger, Ghostty ve Tree-sitter parser'larının varlığı denetlenir; eksik bir bileşen varsa script bunu yazar ve hata koduyla çıkar.

Eklentileri bu makinede güncelledikten sonra `lazy-lock.json` dosyasını commit etmeyi unutmayın; yeni Mac'e taşınan sürümler bu dosyadan gelir.

Claude Code ve Codex için kişisel genel talimatların aslı bu depoda durur: `templates/claude-global.md` ve `templates/codex-global.md`. `~/.claude/CLAUDE.md` ve `~/.codex/AGENTS.md` bunlara bağlanan sembolik bağlantılardır, böylece her dosyanın tek kopyası vardır ve değişiklikler `git status`'ta görünür. İki dosyanın kuralları aynıdır; tek fark commit mesajındaki `Co-Authored-By` satırıdır. Bir kuralı değiştirirken ikisini de güncelleyin. Her ikisinde de, CodeGraph kurucusunun yönettiği bölümün (`<!-- CODEGRAPH_START -->`) dışında, "kod ararken önce CodeGraph" kuralı yazılıdır. Bootstrap bunları kurmaz; yeni Mac'te elle bağlayın (var olan dosya önce yedeklenir):

```sh
mkdir -p ~/.claude ~/.codex
[ -e ~/.claude/CLAUDE.md ] && [ ! -L ~/.claude/CLAUDE.md ] && mv ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
[ -e ~/.codex/AGENTS.md ] && [ ! -L ~/.codex/AGENTS.md ] && mv ~/.codex/AGENTS.md ~/.codex/AGENTS.md.bak
ln -sfn ~/.config/nvim/templates/claude-global.md ~/.claude/CLAUDE.md
ln -sfn ~/.config/nvim/templates/codex-global.md ~/.codex/AGENTS.md
```

Repo kökündeki `AGENTS.md` (Codex) ve ona `@AGENTS.md` ile işaret eden `CLAUDE.md` (Claude Code), o depoya özel kısa kuralları ve "önce CodeGraph" hatırlatmasını taşır.

Bağlantı `~/.config/nvim` yoluna bağlıdır. Bir araç dosyayı yerinde değiştirmek yerine yeniden yazıp adını değiştirirse bağlantı kopar ve `~/.claude/CLAUDE.md` bağımsız bir dosyaya döner; `ls -l ~/.claude/CLAUDE.md ~/.codex/AGENTS.md` ile `->` işaretini görerek denetleyin; `:NeoDoctor` da ikisini denetler.

İsteğe bağlı olarak .NET Framework projeleri için Mono ve Mono hata ayıklama adaptörü kurulabilir (varsayılan olarak kurulmaz; `brew install mono` ve Open VSX'ten SHA-256'sı doğrulanan `mono-debug` 0.16.3 paketi):

```sh
./bootstrap-macos.sh --with-mono
```

Fossil ve Elm gerekmeyen bir Mac'te bunun yerine şunu çalıştırın:

```sh
./bootstrap-macos.sh --no-elm
```

`./bootstrap-macos-csharp.sh` aynı işi yapan kısa bir sarmalayıcıdır.

Bu varyant Elm, `elm-language-server`, Tree-sitter Elm parserı ve Fossil'i kurmaz; C#, debugger, Ghostty, Zsh araçları ve tüm Neovim ayarları korunur.

macOS Terminal'in varsayılan Menlo fontuyla uyum için Nerd Font ikonları kapalıdır.
