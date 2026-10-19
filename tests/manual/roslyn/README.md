# Gerçek Roslyn ile elle kontroller

`tests/run.sh` içinde değildir: yavaşlar ve `~/.dotnet/tools/roslyn-language-server` ister.
Birim testler sunucuyu taklit eder, bu betikler Roslyn'in gerçek davranışını doğrular.

- `./run.sh signature_help`: `()` sonrası her imzanın parametre sayısı (`neo.call_parens` varsayımı).
- `./run.sh cmp_flow`: insert modunda yazıp cmp ile onaylar, satırı ve imleç sütununu yazar.
- `./run.sh type_flow`: tipe duyarlı yer tutucuları (`""`, `x => `, `;`, `[]`, `<>`), `Option-i`, `Option-u`, `Option-Enter` (dokunulmaması ve `;` eklenmesi gereken satırlar dahil) ve `swe` snippet'inin `Tab` akışını gerçek cmp + Roslyn ile dener, sonra tree-sitter ile sözdizimini ve `dotnet build` ile derlemeyi doğrular.

Roslyn veya cmp güncellenince ikisini de çalıştırın. Her çalıştırma 120-150 sn sert zaman aşımına sahiptir.
