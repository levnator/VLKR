# Geschichts-Modul und Fach-Ebene für VLKR

**Datum:** 2026-09-01
**Status:** Design freigegeben, Implementierung ausstehend
**Betrifft:** `index.html` (Single-File-App)

## Ziel

Die App trägt heute ein Fach: *Cahier de Grammaire* (Französisch). Sie soll ein zweites
Fach bekommen — *Geschichte & Staatskunde Schweiz* — mit Schwerpunkt auf der sicheren
Beherrschung von Jahreszahlen und Abläufen. Darüber kommt eine Fach-Wahl als neue
Startseite.

Anlass ist eine anstehende Prüfung. Die Lernziele stammen aus einem Dossier des
Nutzers (Quellen dort: Schweizerische Bundeskanzlei / *Der Bund kurz erklärt*,
Historisches Lexikon der Schweiz, smartvote).

## Harte Randbedingung: keine erfundenen Fakten

Der Inhalt wird **strikt aus dem Dossier** übernommen. Es werden keine Jahreszahlen,
Namen oder Zahlen ergänzt, die dort nicht stehen — auch keine allgemein bekannten wie
das Frauenstimmrecht 1971. Begründung: Die Prüfung wird nach den Vorgaben der
Lehrperson gestellt; zusätzliche Fakten erzeugen Lernaufwand ohne Prüfungsnutzen und
bergen das Risiko, dass Falsches als gesichert dargestellt wird.

Wo das Dossier eine Angabe unscharf lässt (`1830er`, `1870er`, `1918/19`), bleibt sie
unscharf und wird nicht zu einer exakten Jahreszahl verschärft.

## Nicht im Umfang

- Inhaltliche Änderungen am bestehenden Französisch-Teil.
- Änderungen an der Quiz-Engine (Modi, XP, Kombo, Herzen, Timer).
- Serverseitige Persistenz. Der Fortschritt bleibt in `localStorage`.

---

## 1 · Architektur: Fach-Ebene

### Datenstruktur

Ein `SUBJECTS`-Register wird zur obersten Ebene. Jedes Fach ist eine abgeschlossene
Einheit aus Metadaten, Themenliste und Abschnittsliste:

```js
var SUBJECTS = [
  {key:"fr", mark:"C", title:"Cahier de Grammaire", sub:"Französisch",
   topics:FR_TOPICS, sections:FR_SECTIONS},
  {key:"ge", mark:"H", title:"Geschichte", sub:"Staatskunde Schweiz",
   topics:GE_TOPICS, sections:GE_SECTIONS}
];
```

Das heutige globale `TOPICS` wird zu `FR_TOPICS`, das heutige `SECTIONS` zu
`FR_SECTIONS`. Beide behalten ihre Form; es ändert sich nur, wer sie liest.

### Routing

Der Hash wird zweistufig. Die Fach-Wahl ist der neue Wurzelzustand.

| Route | Bedeutung |
| --- | --- |
| `#/` | Fach-Wahl (Startseite) |
| `#/fr/home` | Französisch, Übersicht |
| `#/fr/verbs` | Französisch, Thema Verben |
| `#/ge/zeitstrahl` | Geschichte, Thema Zeitstrahl |
| `#/verbs` (alt) | leitet auf `#/fr/verbs` um |

Die Rückwärtskompatibilität ist billig zu haben und verhindert, dass bestehende
Lesezeichen und der zuletzt besuchte Stand ins Leere laufen.

### Auswirkung auf die Quiz-Engine

Die Engine bleibt unverändert. `makeFeeder`, `bankFor`, `buildPool` und
`makeMixedFeeder` arbeiten heute gegen das globale `TOPICS`; sie bekommen die
Themenliste künftig als Parameter beziehungsweise über `cfg.subject`.

Damit gilt: «Alle Themen» mischt nur innerhalb eines Fachs. Jedes Fach hat seine
eigene Prüfung. Eine fachübergreifende Prüfung ist ausdrücklich nicht vorgesehen —
sie würde Französisch-Formen und Jahreszahlen in einer Session vermengen, was für
die Prüfungsvorbereitung wertlos wäre.

### Auswirkung auf den Fortschritt

- **XP und Level bleiben global.** Ein Lernstand über beide Fächer.
- **Trefferquoten bleiben pro Thema.** Die Geschichts-Themen bekommen `g-`-Präfixe
  (`g-zeitstrahl`, `g-1848`, …), damit sie nicht mit bestehenden Schlüsseln
  kollidieren. Der vorhandene Französisch-Fortschritt bleibt dadurch erhalten.
- Der Speicherschlüssel (`STORE_KEY`) und das Format von `defaultStore()` ändern sich
  nicht; es kommen nur neue Themenschlüssel hinzu.

### Startseite (Fach-Wahl)

Schlanke Übersicht mit einer Karte pro Fach: Kürzel, Titel, Untertitel, Anzahl Themen
und Fortschritt. Darunter der bestehende Level-Balken. Kein Inhalt aus den Fächern
selbst — die Seite ist eine Weiche, kein Dashboard.

Aus dem Schubladen-Menü führt ein Eintrag jederzeit zurück zur Fach-Wahl.

---

## 2 · Die sieben Geschichts-Themen

| Nr. | Schlüssel | Titel | Inhalt |
| --- | --- | --- | --- |
| 01 | `g-zeitstrahl` | Zeitstrahl | Alle datierten Ereignisse chronologisch |
| 02 | `g-1848` | 1848 · Bundesstaat | Verfassungen 1798–1848, Sonderbundskrieg |
| 03 | `g-demokratie` | Demokratie & Konkordanz | 1874, 1891, Konkordanz-Schritte, Parteien |
| 04 | `g-volksrechte` | Volksrechte | Initiative, fakultatives und obligatorisches Referendum |
| 05 | `g-initiative` | Volksinitiative | Ablauf in fünf Schritten |
| 06 | `g-weltkrieg` | Weltkrieg & Zwischenkriegszeit | 1914–1945 |
| 07 | `g-staatslehre` | Staatslehre | Glossar, Gewaltenteilung, smartspider |

---

## 3 · Der Zeitstrahl als Signatur

### Prinzip

Alle datierten Ereignisse liegen in **einer** Datenstruktur. Diese rendert zweierlei:
die chronologische Referenz zum Lesen und die Fragenbank für den Datums-Drill. Eine
Jahreszahl steht damit an genau einer Stelle im Code — Referenz und Drill können nicht
auseinanderlaufen.

```js
{y:1847, exact:true, t:"Sonderbundskrieg",
 d:"Bürgerkrieg vom 3. bis 29. November; letzte militärische Auseinandersetzung auf Schweizer Boden.",
 topic:"g-1848"}
```

Das Feld `exact` unterscheidet gesicherte Jahreszahlen von unscharfen Angaben.
Nur Einträge mit `exact:true` erzeugen Fragen nach dem genauen Jahr.

### Datenbestand

26 Einträge, davon 23 mit exaktem Jahr. Die drei unscharfen sind markiert.

| Jahr | exakt | Ereignis |
| --- | --- | --- |
| 1798 | ja | Helvetische Verfassung in Kraft; zentralistisch, kein Raum für Kantone und Gemeinden |
| 1803 | ja | Mediationsakte, von Napoleon diktiert; stärkt den Föderalismus |
| 1815 | ja | Bundesvertrag, am Wiener Kongress vereinbart; Schweiz wieder reiner Staatenbund |
| 1830er | **nein** | Liberale und Radikale arbeiten auf einen zentralen Bundesstaat hin |
| 1847 | ja | Sonderbundskrieg, 3.–29. November; letzte militärische Auseinandersetzung auf Schweizer Boden |
| 1848 | ja | Bundesverfassung vom 12. September; vom Staatenbund zum Bundesstaat |
| 1870er | **nein** | Kulturkampf als Gipfel des weltanschaulichen Konflikts |
| 1874 | ja | Totalrevision der BV; fakultatives Gesetzesreferendum; Übergang zur halbdirekten Demokratie |
| 1888 | ja | Gründung der Sozialdemokratischen Partei (SP) |
| 1891 | ja | Volksinitiative auf Teilrevision der BV als formulierter Entwurf |
| 1891 | ja | Josef Zemp als erster Nicht-Freisinniger in den Bundesrat |
| 1918 | ja | Landesstreik im November unter dem Oltener Aktionskomitee; nach drei Tagen abgebrochen |
| 1918 | ja | Gründung der Bauern-, Gewerbe- und Bürgerpartei (BGB, heute SVP) |
| 1918/19 | **nein** | Spanische Grippe; über 24'400 Todesopfer |
| 1919 | ja | Rasche Einführung der 48-Stunden-Woche |
| 1919 | ja | Nationalratswahl erstmals im Proporz; beendet die absolute Freisinn-Mehrheit |
| 1929 | ja | Rudolf Minger (BGB) in den Bundesrat |
| 1933 | ja | Frontenfrühling, Höhepunkt der Frontenbewegung |
| 1935 | ja | Totalrevisions-Initiative zur faschistischen Umgestaltung mit über 70 % Nein verworfen |
| 1938 | ja | Annahme des einheitlichen Strafgesetzbuchs |
| 1938 | ja | «J-Stempel» mit NS-Deutschland vereinbart; Konferenz von Évian, Schweiz rein als Transitland |
| 1940 | ja | Letzte zivile Hinrichtung (Hans Vollenweider) |
| 1942 | ja | Strafgesetzbuch tritt in Kraft |
| 1943 | ja | SP erstmals im Bundesrat |
| 1959 | ja | Zauberformel 2:2:2:1 |
| 1999 | ja | Verfassungsrechtliches Verbot der Todesstrafe |

### Drei Fragetypen

1. **Jahr nennen** (Eingabe) — «In welchem Jahr: Sonderbundskrieg?» → `1847`.
   Nur aus `exact:true`. Akzeptiert die vierstellige Jahreszahl.
2. **Ereignis zuordnen** (Auswahl) — «Was geschah 1874?» Distraktoren sind *echte*
   Ereignisse aus dem Zeitstrahl, bevorzugt zeitlich benachbarte. Falsche Antworten
   sind dadurch plausibel und der Drill zwingt zum Unterscheiden statt zum Ausschliessen.
3. **Reihenfolge** (Auswahl) — «Was kam zuerst?» mit zwei Ereignissen.

Typ 3 ist der eigentliche Zweck des Moduls: Einzelne Jahreszahlen lassen sich raten,
die Reihenfolge zweier naher Ereignisse nicht. Paare werden bevorzugt aus zeitlich
nahen Ereignissen gebildet, weil weit auseinanderliegende Paare trivial sind.

---

## 4 · Zahlen-Drill

Eigenes Set mit den prüfungstypischen Zahlen. Alle Werte stammen aus dem Dossier.

| Gegenstand | Wert |
| --- | --- |
| Volksinitiative, Unterschriften | 100'000 |
| Volksinitiative, Sammelfrist | 18 Monate |
| Fakultatives Referendum, Unterschriften | 50'000 (oder 8 Kantone) |
| Fakultatives Referendum, Frist | 100 Tage ab Veröffentlichung |
| Initiativkomitee | mindestens 7, höchstens 27 Stimmberechtigte |
| Ständemehr | mindestens 12 von 23 Kantonsstimmen |
| Nationalrat | 200 Sitze |
| Ständerat | 46 Sitze |
| Bundesrat | 7 gleichberechtigte Mitglieder |
| Zauberformel (1959) | 2:2:2:1 |
| smartspider | 8 Achsen, Skala 0 bis 100 |
| Spanische Grippe | über 24'400 Todesopfer |
| Totalrevisions-Initiative 1935 | über 70 % Nein |

Die acht Sonderbund-Kantone bilden ein eigenes Aufzählungs-Set: Luzern, Schwyz, Uri,
Zug, Obwalden, Nidwalden, Freiburg, Wallis.

---

## 5 · Inhalt der übrigen Themen

Die Referenztexte werden aus dem Dossier übernommen. Fragenbänke entstehen pro Thema
über `build`-Funktionen nach bestehendem Muster (`buildGenderBank` als Vorbild).

- **`g-1848`** — Verfassungsreihe 1798 → 1803 → 1815 → 1848 mit ihren Kennzeichen;
  Sonderbundskrieg (Anlass, Dauer, Konfession der Lager, Kriegsziel); Staatenbund
  gegenüber Bundesstaat; die BV von 1848 als demokratische Insel unter Monarchien;
  Aussöhnung erst über die Revision von 1874.
- **`g-demokratie`** — Freisinn als dominierende Kraft und Sieger von 1847; Ziele der
  Radikal-Liberalen; Gegenposition der Katholisch-Konservativen; Spaltung in Demokraten
  und Gemässigte; SP-Gründung 1888; repräsentativ bis 1874, danach halbdirekt;
  Referendum als «Bremse», Initiative als «Gaspedal»; Konkordanz gegenüber
  Konkurrenzdemokratie; Zemp 1891, Minger 1929, SP 1943/1959.
- **`g-volksrechte`** — Vergleichstabelle der drei Instrumente nach Zweck, Quorum,
  Frist und erforderlichem Mehr; die drei Fälle des obligatorischen Referendums.
- **`g-initiative`** — die fünf Schritte von der Vorprüfung bis zur Volksabstimmung;
  Prüfkriterien der Gültigkeit; direkter gegenüber indirektem Gegenvorschlag.
- **`g-weltkrieg`** — General Ulrich Wille und die Obersten-Affäre; Röstigraben;
  fehlender Erwerbsersatz und späte Rationierung; Landesstreik mit seinen vier
  Forderungen; BGB-Gründung; Proporz 1919; Frontenfrühling und Geistige
  Landesverteidigung; Strafgesetzbuch, Todesstrafe und Asylpraxis samt J-Stempel.
- **`g-staatslehre`** — Glossar (Konkordanz, Bundesstaat/Staatenbund, Kulturkampf);
  Gewaltenteilung mit Legislative, Exekutive und Judikative; smartspider mit acht
  Achsen und den vier Parteiprofilen.

---

## 6 · Gestaltung

Die bestehende Formensprache wird übernommen: liniertes Papier, `Newsreader` für
Überschriften, `IBM Plex Mono` für Zahlen, roter Akzent. Das Fach Geschichte bekommt
kein eigenes Farbschema — zwei konkurrierende Paletten in einer App würden die
Wiedererkennbarkeit zerstören.

Der Zeitstrahl ist das einzige neue visuelle Element: eine vertikale Achse am linken
Rand, die die vorhandene Randlinie des Heftblatts aufnimmt, mit Jahreszahlen in der
Mono-Schrift als Ankern. Unscharfe Angaben (`1830er`) werden sichtbar anders gesetzt
als exakte Jahreszahlen, damit die Unschärfe auch beim Lernen sichtbar bleibt.

Mobil gilt der bestehende Massstab: Der Zeitstrahl bleibt einspaltig, die
Vergleichstabelle der Volksrechte scrollt horizontal mit fixierter erster Spalte wie
die Konjugationstabellen.

---

## 7 · Verifikation

- Alle Jahreszahlen und Zahlen im Code gegen die Tabellen in Abschnitt 3 und 4 prüfen.
- Kein Eintrag mit `exact:false` darf in einer Frage nach dem genauen Jahr erscheinen.
- Bestehender Französisch-Fortschritt im `localStorage` überlebt den Umbau.
- Alte Routen (`#/verbs`) landen auf der neuen Entsprechung.
- «Alle Themen» eines Fachs zieht keine Fragen aus dem anderen Fach.
- Rendering auf 390 px und auf Desktop, hell und dunkel, ohne horizontalen Überlauf.
- Keine Konsolenfehler.
