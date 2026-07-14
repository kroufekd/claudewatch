# ClaudeWatch

macOS menu bar aplikace, která ukazuje aktuální využití limitů **Claude Code**
(session 5h, týdenní, týdenní per-model) jako progress bar přímo v menu baru.
Umí sledovat víc předplatných najednou a upozorní tě, když se limit blíží stropu
nebo když se zase uvolní.

## Pro koho to je

Používáš Claude Code a chceš mít v menu baru pořád na očích, kolik ze session /
týdenního limitu jsi už spálil, aniž bys pořád psal `/usage`. ClaudeWatch čte
stejná data jako `/usage`, takže nic navíc nenastavuješ.

## Předpoklady

- **macOS 13** (Ventura) nebo novější
- **Claude Code** nainstalovaný a přihlášený (`claude` v terminálu, aspoň jednou `/login`).
  ClaudeWatch si bere token z Keychainu, který si Claude Code sám spravuje.
- **Xcode Command Line Tools** kvůli `swift` (`xcode-select --install`)

## Rychlá instalace

```bash
git clone https://github.com/kroufekd/claudewatch.git
cd claudewatch
./install.sh
```

`install.sh` udělá build, zkopíruje appku do `~/Applications` a zaregistruje
LaunchAgent, takže naběhne po každém přihlášení a drží se běžet. Po prvním startu
tě macOS jednou zeptá na povolení notifikací — dej Povolit.

Odinstalace (včetně uložených tokenů):

```bash
./uninstall.sh
```

Jen build bez instalace:

```bash
./bundle.sh && open ClaudeWatch.app
```

## Jak to funguje

- **Zdroj dat:** stejné OAuth endpointy, které používá `/usage` v Claude Code:
  - `GET https://api.anthropic.com/api/oauth/usage` — procenta využití + časy resetů
  - `GET https://api.anthropic.com/api/oauth/profile` — identifikace účtu (email, uuid)
  - `POST https://console.anthropic.com/v1/oauth/token` — refresh tokenu
- **Aktivní účet:** token se čte přímo z Keychain položky `Claude Code-credentials`,
  kterou spravuje Claude Code. Jeho token se **nikdy** nerefreshuje (rotaci řeší Claude
  Code sám — kdyby ho rotovala i tahle appka, rozbila by ti přihlášení).
- **Druhý účet:** jakmile se v Claude Code přihlásíš druhým účtem, ClaudeWatch si
  jeho tokeny uloží (Keychain položka `ClaudeWatch-accounts`) a dál je refreshuje sám,
  takže usage vidíš pro oba účty současně bez ohledu na to, který je zrovna přihlášený.
- **Polling:** usage endpoint má tvrdý rate limit, takže appka polluje jednou za 120 s
  (+ okamžitě při otevření dashboardu, throttlováno na 30 s). Po HTTP 429 jde na 5 min
  cooldown a mezi účty drží 10 s pauzu.

## Menu bar

Barevný progress bar = session (5h) limit aktivního účtu.
Zelená < 60 %, oranžová < 85 %, červená ≥ 85 %.

Levý klik otevře dashboard: velký readout session limitu aktivního účtu + rozklikávací
sekce s týdenními / per-model limity a druhým účtem, časy resetů. Pravý klik = rychlé
menu (obnovit / ukončit).

## Notifikace

Appka porovnává každý poll s předchozím a pošle lokální notifikaci na dvou hranách,
pro **kterýkoliv** sledovaný účet a každý limit zvlášť:

- **Limit se uvolnil** — okno se přetočilo (`resetsAt` skočil dál) a předtím bylo
  využito aspoň z 50 %. Např. session 5h se resetla a máš zase plný budget.
- **Limit skoro vyčerpán** — využití překročilo 90 % (jen na té hraně, ne opakovaně
  každých pár minut).

Prahy jsou konstanty v `Sources/ClaudeWatch/NotificationService.swift`
(`nearLimitThreshold`, `resetAnnounceThreshold`), takže se dají snadno přenastavit.

Notifikace se řídí polováním (120 s), takže dorazí do ~2 minut od události.

## Zachycení druhého účtu

1. V Claude Code spusť `/login` a přihlas se druhým předplatným.
2. Do ~2 minut si ClaudeWatch účet uloží (objeví se druhá karta v dashboardu).
3. Můžeš se přepnout zpátky — oba účty zůstanou sledované.

Pokud refresh token druhého účtu přestane platit (např. odhlášení všech relací),
karta ukáže chybu — stačí se tím účtem jednou znovu přihlásit v Claude Code.

## Vývoj

```bash
swift build      # debug build
swift test       # unit testy (parsování API, formátování)
```

Kód je rozdělený na malé soubory v `Sources/ClaudeWatch/`:

| Soubor | Co dělá |
| --- | --- |
| `main.swift` | vstupní bod, accessory app bez dock ikony |
| `AppDelegate.swift` | status item, popover, propojení store + notifikace |
| `UsageStore.swift` | stav, polling, refresh tokenů, rate-limit logika |
| `AnthropicAPI.swift` | HTTP volání OAuth endpointů |
| `KeychainService.swift` | čtení Claude Code credentials + ukládání účtů |
| `NotificationService.swift` | hranové notifikace na reset / blížící se limit |
| `DashboardView.swift` | SwiftUI popover |
| `Models.swift`, `Format.swift` | datové typy a formátování |

## Poznámka

Neoficiální nástroj, používá nedokumentované OAuth endpointy Claude Code. Nic
neposílá nikam ven — všechno běží lokálně, tokeny zůstávají v tvém Keychainu.
Není spojený s Anthropicem.
