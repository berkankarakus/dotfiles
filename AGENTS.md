# AGENTS.md

Bu repo macOS icin Neovim C# yapilandirmasi, zsh ve Ghostty sablonlari ile kurulum betigini icerir.
Degisikliklerden once README ve ilgili testleri inceleyin.


## Kod ararken önce CodeGraph

Bu depoda `.codegraph/` indeksi var. Kodu bulmak ya da anlamak için `rg`, `grep`, `find` ya da dosya okumadan
**önce** `codegraph_explore` (MCP) ya da kabukta `codegraph explore "<sorgu>"` çağır. Bir sembolün kaynağı,
çağıranları ve etkilediği yerler tek çağrıda gelir. `rg`/okuma yalnızca CodeGraph'in kapsamadığı şeyler
(yapılandırma, belgeler, SQL) ve ayrıntı doğrulama için kalır.

Ortak calisma kurallari `templates/claude-global.md` ve
`templates/codex-global.md` dosyalarinda tutulabilir.
