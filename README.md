# ClaudeWatch

macOS menu bar tracker limitů **Claude Code**. Ukazuje využití session (5h),
týdenního i per-model limitu jako barevný proužek v menu baru, zvládne víc účtů
naráz a pošle notifikaci, když se limit blíží stropu nebo se zase uvolní.

Data bere ze stejných endpointů jako `/usage` v Claude Code. Vše běží lokálně,
tokeny zůstávají v tvém Keychainu. Neoficiální nástroj, není spojený s Anthropicem.

**Předpoklady:** macOS 13+, přihlášený Claude Code, Xcode Command Line Tools (`swift`).

## Instalace

```bash
git clone https://github.com/kroufekd/claudewatch.git
cd claudewatch
./install.sh
```

## Prompt pro agenta

Máš Claude Code (nebo jinýho coding agenta)? Zkopíruj mu tohle:

```
Nainstaluj mi ClaudeWatch — macOS menu bar tracker limitů Claude Code.

1. git clone https://github.com/kroufekd/claudewatch.git do vhodné složky
2. cd claudewatch && ./install.sh
   (build + kopie do ~/Applications + LaunchAgent, naběhne po přihlášení)
3. Po startu potvrď systémový dialog na povolení notifikací.
4. Ověř že proces běží: pgrep -lf ClaudeWatch

Když chybí swift, řekni mi ať pustím: xcode-select --install
Odinstalace: ./uninstall.sh
```
