# Gerçek Roslyn ile elle kontroller

`tests/run.sh` içinde değildir: yavaşlar ve `~/.dotnet/tools/roslyn-language-server` ister.
Birim testler sunucuyu taklit eder, bu betikler Roslyn'in gerçek davranışını doğrular.

- `./run.sh signature_help`: `()` sonrası her imzanın parametre sayısı (`neo.call_parens` varsayımı).
- `./run.sh cmp_flow`: insert modunda yazıp cmp ile onaylar, satırı ve imleç sütununu yazar.

Roslyn veya cmp güncellenince ikisini de çalıştırın. Her çalıştırma 120-150 sn sert zaman aşımına sahiptir.
