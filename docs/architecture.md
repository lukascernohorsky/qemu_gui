# Architektura QEMU GUI (Tcl/Tk)

Tento dokument shrnuje aktuální komponenty prototypu a jejich spolupráci.

## Stavy jobů a fronta
- **Namespace `::qemu`** drží `jobQueue`, `jobDetails`, `jobLogs` a aktuální `runningJob`.
- **Enqueue**: `enqueueJob kind data` vytvoří job se stavem `queued`, uloží jej do `jobDetails` a přidá do fronty.
- **Asynchronní běh**: `runJobAsync` používá `after` kroky (5→35→65→90→finish) a aktualizuje stav přes `updateJobProgress`.
- **Dokončení**: `finishJob` volá `executeJobWork` (např. `start_vm`, `diagnostics_export`, `mock_new_vm`) a `completeJob` zapíše log, nastaví status bar a spustí další job.
- **Stavový řádek** (`.main.status`): ukazuje text + progres; kód chyby/stavu je uložen v `statusCode` a propisuje se do textu statusu.
- **Logy**: `jobLogs` ukládají záznamy s ID, druhem jobu, zprávou a kódem. `openLogViewer` poskytuje filtr a přehrání/re-render přes `renderLogViewer`.

## Inventář a mock backend
- **Mock capabilities** (`mockCapabilities`) popisují akce/limity pro `compute`, `storage`, `network`.
- **Mock inventory** (`mockInventory`) drží stub VM položky. `openMockBackendWindow` zobrazuje tabulku, detail capability a tlačítko „New VM (mock)“ volá `enqueueJob mock_new_vm`.
- **Capability detaily**: `renderCapabilitySummary` formátuje akce/limity; detail zobrazuje `showMockDetail` při výběru řádku.

## Diagnostika
- **Sběr**: `collectDiagnosticsData` vrací slovník s inventářem VM (včetně redakce citlivých polí), job logy, capability reportem, mock inventářem a tématy (`mockTopics`).
- **Export**: `writeDiagnosticsBundle` zapisuje `diagnostics.json`, `capability_report.txt`, `topics.txt` do dočasného adresáře a zabaluje do `tar.gz` v `./diagnostics/`.
- **Redakce**: `collectDiagnosticsData` nahrazuje hodnoty `iso`, `firmware` a cest v discích textem `<redacted>`.

## GUI vrstvy
- **Hlavní okno**: toolbar (Nový/Upravit/Smazat/Start/Příkaz/Nastavení/Logy/Mock backend/Export diagnostiky), seznam VM, textový detail a stavový řádek s progress barem.
- **Dialogy**: VM formulář (obecné, úložiště, síť, zobrazení, pokročilé), log viewer, mock inventář, nastavení cest.
- **Headless mód**: proměnná prostředí `QEMU_GUI_HEADLESS=1` přeskočí načtení Tk a spuštění UI, což umožňuje testování logiky.
