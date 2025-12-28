# Mapování příkazů a job stavů

## Stavový model jobů
- `queued` → `running` (progress 5/35/65/90) → `completed`/`failed`.
- `statusCode` ukládá číselný kód; v GUI se zobrazuje v textu stavového řádku.
- Log viewer umožňuje filtrování podle textu zprávy/druhu jobu a přehrání (= opětovné vykreslení dle filtru).

## Operace obsluhované job runnerem
- `start_vm`: připraví příkaz QEMU (`buildCommand`), vyžádá potvrzení a spustí proces; běží asynchronně přes frontu.
- `diagnostics_export`: volá `collectDiagnosticsData` a zabalí výstup přes `writeDiagnosticsBundle` do `diagnostics/*.tar.gz`.
- `mock_new_vm`: vytvoří novou položku mock inventáře (`createMockEntry`) a záznam v logu.

## Diagnostické soubory
- `diagnostics.json`: serializovaný slovník s inventářem VM, redigovanými cestami (iso/firmware/disks), job logy, capability reportem a mock tématy.
- `capability_report.txt`: lidsky čitelný přehled akce/limitů pro jednotlivé capability.
- `topics.txt`: seznam témat s jejich `scale` (např. lifecycle/performance/compliance).
- Celý balík je zabalen do `tar.gz`; cílová cesta je automaticky vytvořena v `./diagnostics/` pokud není zadána ručně.

## Mapování UI → akce
- **Logy**: tlačítko „Logy“ otevře filtr a přehrání záznamů (`openLogViewer`).
- **Mock backend**: tlačítko otevře okno s inventářem, tlačítko „New VM (mock)“ přidá položku přes job queue a detail panel zobrazuje akce/limity capability.
- **Export diagnostiky**: tlačítko přidá `diagnostics_export` job do fronty a ukáže průběh ve stavovém řádku.
