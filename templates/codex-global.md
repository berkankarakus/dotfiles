# Kod stili (C#)

- Kodun mümkün olduğunca okunabilir olmasını istiyorum. İlk yazımda okunabilir yaz ki sonradan refactor gerekmesin. Kısa ama sıkışık yazmak yerine biraz uzun ama rahat okunan kodu tercih et.
- İfade gövdeli (`=>`) üye yalnızca tamamı tek satıra sığıyorsa kullanılabilir (ör. `public int Count => _items.Count;`). Gövde birden fazla satıra yayılıyorsa blok gövde + açık `return` + adlandırılmış yerel değişkenler kullan. Çok satırlı `=> new() { ... }`, `=> ... ?? new ...` ve tek ifadeye sıkıştırılmış çağrılardan kaçın.
- Null/boş durumu `??` yerine ternary veya `if (x is null) ...` ile yaz.
- `if`'ten ve `return`'den önce her zaman boş satır bırak (bloğun ilk ifadesi değilse). `throw` öncesi ve mantıksal ifade grupları arasında da boş satır koy; ardışık ifadeleri yapıştırma.
- Tek satıra sığmayan metot çağrısında her argüman ayrı satırda olur ve kapanış `);` kendi satırında durur, son argümandan sonra virgül konmaz:

```csharp
var temporaryFilePath = Path.Combine(
    directoryPath,
    $".{Path.GetFileName(filePath)}.{Guid.NewGuid():N}.tmp"
);
```

- Tek satıra sığmayan metot tanımında (declaration) da aynı biçim geçerli: her parametre ayrı satırda, kapanış `)` kendi satırında, ardından `{` bir sonraki satırda:

```csharp
public async Task<bool> WriteAsync(
    string vendorName,
    int categoryCode,
    IReadOnlyList<GeneratedReportProduct> products,
    bool includeNov2025MinPrice,
    CancellationToken cancellationToken
)
{
```

- `try` bloğunun kapanış `}`'i ile `catch` arasında, ardışık `catch` blokları arasında ve `finally`'den önce boş satır bırak:

```csharp
try
{
    ...
}

catch (OperationCanceledException)
{
    throw;
}

catch (Exception exception)
{
    ...
}
```

- Primary constructor'da her parametre ayrı satırda yazılır, kapanış `)` kendi satırında durur ve implement edilen arayüz aynı satırda `)`'in ardından gelir:

```csharp
public sealed class GzipReportWriter(
    IOptions<VendorReportOptions> options,
    IAppLogger<GzipReportWriter> logger
) : ICompressedReportWriter
{
```

- Mevcut kardeş sınıflarla tutarlılık gerekiyorsa (ör. aynı kalıptaki QueryProvider'lar) önce sor.

# Commit ve push

- Use a short conventional commit prefix such as `feat:`, `fix:`, `docs:` or `test:`.
- Create commits and pushes only when explicitly requested by the repository owner.
- Avoid unrelated renames and scope expansion.
- Push edilmemiş commit'i amend etmek serbest. Push edilmiş commit için ek commit at.
- Keep messages concrete and avoid ambiguous references.
- Mesajlarda belirsiz ifadelerden kaçın (ör. "buradan" yerine somut yaz).

# Kod arama: önce CodeGraph

- Bir projeyi incelerken, bir sembolü ararken ya da "bu nasıl çalışıyor" sorusunu yanıtlarken **ilk araç CodeGraph'tir**: MCP aracı `codegraph_explore`, yoksa kabukta `codegraph explore "<sorgu>"`. `rg`, `grep`, `find` ve dosya okuma ondan **sonra** gelir; yalnızca CodeGraph'in kapsamadığı şeyler (yapılandırma, belgeler, SQL) ve ayrıntı doğrulama için kullan.
- When inspecting another project, use its absolute path and skip CodeGraph if it has no `.codegraph/` directory.
- CodeGraph SQL dosyalarını indekslemez. SQL için `rg` ya da `sqldeps` kullan.

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
