# Taccuino Fisarmonica 🪗

Un **blocco note musicale** (Flutter, Android + Web) per annotare al volo assoli
di fisarmonica toccando una tastiera verticale. Ogni nota è scritta come
**nome + ottava + trattini di durata** (es. `La4--`). Funziona offline e
salva il lavoro tra un avvio e l'altro.

## Caratteristiche

- Pianoforte **verticale** Do4…Mi6 (MIDI 60–88), tasti in madreperla e ottone,
  neri posizionati sui confini corretti, scroll con avvio centrato.
- Notazione: `La4`, `Sol#5-`, accordi `[Do4 Mi4 Sol4]--`, diteggiatura `La4(3)`.
- Modalità **accordo** (impila/rimuove note su una voce), durata `+`/`−` (0–8),
  **diteggiatura 1–5** per nota, cancella `⌫`, selezione voce toccandola.
- **Play ▶** per ascoltare la sequenza (rispetta le durate) e **Stop**.
- Modalità **prova**: disattiva la scrittura, i tasti suonano soltanto.
- Editing: inserimento **dopo** la voce selezionata (anche in mezzo), **⌫**
  toglie solo la nota a fuoco negli accordi, **tieni premuto e trascina** per
  riordinare; i tasti evidenziati mostrano la diteggiatura.
- Toggle **nomi** IT (Do Re Mi) / EN (C D E) e **audio** (♪ / muto).
- Audio sintetizzato "musette" (due triangolari scordati ±7 cent):
  su Android via `flutter_soloud` (WAV in memoria), sul Web via Web Audio API.
- **Copia** negli appunti, **svuota**, **persistenza** con `shared_preferences`.
- **Salva con nome** e **Carica** (lista delle musiche salvate, con rinomina
  ed elimina) dal menu ☰ in alto.
- **👁 Vista a schermo intero**: note formattate con a-capo automatici, senza
  tastiera, con **+/−** per ridimensionare il testo.
- Font: Fraunces (titoli) + Space Mono (note), palette legno/ottone/avorio.
- Icona app (Android + Web) generata da `assets/icon/app_icon.png`.

## Eseguire in locale

```bash
flutter pub get
flutter run                 # dispositivo/emulatore Android
flutter run -d chrome       # web
```

> Le cartelle di piattaforma (`android/`, `web/`) non sono versionate: vengono
> rigenerate con `flutter create --platforms=android,web .` (lo fa anche la CI).
> Se lavori in locale la prima volta, esegui quel comando prima di `flutter run`.

## Deploy automatico (GitHub Actions)

Il workflow [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml):

- **Web → GitHub Pages**: build con `--base-href` pari al nome del repo,
  pubblicazione sul ramo `gh-pages` e impostazione automatica della sorgente
  Pages via API (nessuna configurazione manuale). Questo percorso evita
  l'ambiente `github-pages`, le cui regole bloccavano il deploy dal ramo.
  URL: `https://ianes1978.github.io/Taccuino-Fisarmonica/`
- **Android → Release APK**: build `--release`, caricato come artifact di
  workflow e pubblicato nella release `apk-latest` (sui rami `main`/`master`).

Parte ad ogni push sui rami principali (e sul ramo di sviluppo) o manualmente
da **Actions → build-and-deploy → Run workflow**.
