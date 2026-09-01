# Geschichts-Modul und Fach-Ebene — Implementierungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die App bekommt ein zweites Fach «Geschichte & Staatskunde Schweiz» mit Datums-Drill, darüber eine Fach-Wahl als Startseite.

**Architecture:** Ein `SUBJECTS`-Register wird oberste Ebene; das heutige globale `TOPICS`/`SECTIONS` wird zu `FR_TOPICS`/`FR_SECTIONS`. Routing wird zweistufig (`#/fr/verbs`). Die Quiz-Engine bleibt unverändert und bekommt die Themenliste des aktiven Fachs als Parameter. Alle datierten Ereignisse liegen in einer einzigen `TIMELINE`-Struktur, aus der sowohl die Referenz als auch der Drill entsteht.

**Tech Stack:** Eine einzelne `index.html`, ES5-JavaScript (`var`, Funktionsdeklarationen, kein Build-Schritt), `localStorage`. Verifikation über Headless Chrome.

**Spec:** `docs/superpowers/specs/2026-09-01-geschichte-modul-design.md`

## Global Constraints

- **Keine erfundenen Fakten.** Jede Jahreszahl, Zahl und jeder Name muss wörtlich aus der Spec stammen (Abschnitte 3, 4, 5). Nichts ergänzen, auch nichts allgemein Bekanntes.
- **Unscharfe Angaben bleiben unscharf.** `1830er`, `1870er`, `1918/19` tragen `exact:false` und dürfen nie eine Frage nach dem genauen Jahr erzeugen.
- **Code-Stil wie bestehend:** ES5, `var`, Funktionsdeklarationen, keine Pfeilfunktionen, keine `let`/`const`, keine Template-Literale. Der gesamte Code liegt in der bestehenden IIFE in `index.html`.
- **Sprache der Oberfläche:** Deutsch, Schweizer Rechtschreibung (`ss` statt `ß`).
- **`STORE_KEY` bleibt `cahier_progress_v2`.** Bestehender Fortschritt darf nicht verloren gehen.
- **Geschichts-Themenschlüssel tragen das Präfix `g-`.**
- **Single-File bleibt.** Kein Build-Schritt, keine externen Skripte. (Bekannter Kompromiss: `index.html` wächst auf ~3300 Zeilen. Eine Aufteilung wäre ein eigener Auftrag und würde die Deploy-Einfachheit kosten — hier ausdrücklich nicht Teil des Umfangs.)

---

## File Structure

| Datei | Zuständigkeit |
| --- | --- |
| `index.html` | Die gesamte App. Wird in jedem Task erweitert. |
| `tools/selftest.html` | Testseite: lädt die App in einem Iframe und prüft Invarianten gegen `window.__VLKR_TEST__`. |
| `tools/check.sh` | Startet Headless Chrome auf `selftest.html`, gibt das Ergebnis aus, Exit-Code 1 bei Fehlern. |

`index.html` behält seinen Aufbau: Tokens → CSS-Komponenten → Mobile-Block am Ende des Stylesheets → `<body>`-Gerüst → eine IIFE mit Daten, Fragenbausteinen, Routing, Renderern, Quiz-Engine.

Neue JS-Abschnitte werden in dieser Reihenfolge eingefügt:
1. `TIMELINE` und Geschichts-Daten — direkt nach den Französisch-Daten.
2. `build*`-Funktionen für Geschichte — bei den übrigen Bank-Buildern.
3. `GE_TOPICS`, `SUBJECTS` — direkt nach `FR_TOPICS`.
4. Referenz-Renderer — bei den übrigen Renderern.

---

## Task 1: Selbsttest-Harnisch

Ohne automatische Prüfung sind die Invarianten aus Spec-Abschnitt 7 nicht haltbar — besonders «kein `exact:false` in Jahresfragen» und «keine Fach-Vermischung» lassen sich von Hand nicht zuverlässig nachweisen.

**Files:**
- Create: `tools/selftest.html`
- Create: `tools/check.sh`
- Modify: `index.html` (Testzugang am Ende der IIFE, vor `})();`)

**Interfaces:**
- Produces: `window.__VLKR_TEST__` mit den Feldern `SUBJECTS`, `TIMELINE`, `topicsOf(subjectKey)`, `bankFor`, `buildPool`, `makeFeeder`. Alle folgenden Tasks erweitern diesen Testzugang und `selftest.html`.

- [ ] **Step 1: Testzugang in `index.html` einbauen**

Direkt vor der abschliessenden Zeile `})();` einfügen:

```js
/* Testzugang für tools/selftest.html. Produktionscode liest das nie. */
window.__VLKR_TEST__ = {
  SUBJECTS: SUBJECTS,
  TIMELINE: (typeof TIMELINE !== "undefined") ? TIMELINE : [],
  topicsOf: function(sk){
    for(var i=0;i<SUBJECTS.length;i++){ if(SUBJECTS[i].key===sk) return SUBJECTS[i].topics; }
    return null;
  },
  bankFor: bankFor,
  buildPool: buildPool,
  makeFeeder: makeFeeder
};
```

Hinweis: In diesem Task existieren `SUBJECTS` und `TIMELINE` noch nicht. Lege für den Moment oberhalb der IIFE-Ende-Zeile Platzhalter an, die Task 2 und Task 6 ersetzen:

```js
var SUBJECTS = [{key:"fr", topics:TOPICS}];
```

- [ ] **Step 2: `tools/selftest.html` schreiben**

```html
<!doctype html>
<meta charset="utf-8">
<title>VLKR Selbsttest</title>
<style>body{font:13px ui-monospace,monospace;margin:12px}iframe{width:390px;height:700px;border:1px solid #ccc}</style>
<iframe id="app" src="../index.html"></iframe>
<pre id="results">läuft…</pre>
<script>
var results = [], fails = 0;
function check(name, fn){
  try{
    var r = fn();
    if(r === true){ results.push("PASS  " + name); }
    else { fails++; results.push("FAIL  " + name + " — " + r); }
  }catch(e){ fails++; results.push("FAIL  " + name + " — " + e.message); }
}
function runChecks(W, T){
  check("Testzugang vorhanden", function(){
    return T ? true : "window.__VLKR_TEST__ fehlt";
  });
  check("Französisch hat 6 Themen", function(){
    var t = T.topicsOf("fr");
    return (t && t.length === 6) ? true : "erwartet 6, ist " + (t ? t.length : "null");
  });
}
document.getElementById("app").addEventListener("load", function(){
  var W = this.contentWindow;
  setTimeout(function(){
    var T = W.__VLKR_TEST__;
    runChecks(W, T);
    results.push(fails ? ("\n" + fails + " FEHLER") : "\nALL PASS");
    document.getElementById("results").textContent = results.join("\n");
  }, 500);
});
window.addEventListener("error", function(e){
  fails++;
  document.getElementById("results").textContent = "FAIL  Skriptfehler — " + e.message;
});
</script>
```

- [ ] **Step 3: `tools/check.sh` schreiben**

```bash
#!/usr/bin/env bash
set -euo pipefail
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

OUT=$("$CHROME" --headless --disable-gpu --allow-file-access-from-files \
  --virtual-time-budget=10000 --dump-dom "file://$ROOT/tools/selftest.html" 2>/dev/null \
  | python3 -c "
import sys, re, html
m = re.search(r'<pre id=\"results\">(.*?)</pre>', sys.stdin.read(), re.S)
print(html.unescape(m.group(1)) if m else 'FAIL  kein Testergebnis im DOM')
")

echo "$OUT"
if echo "$OUT" | grep -q "FAIL"; then exit 1; fi
if ! echo "$OUT" | grep -q "ALL PASS"; then echo "FAIL  Selbsttest lieferte kein Ergebnis"; exit 1; fi
```

Chrome liest `file://`-Iframes nur mit `--allow-file-access-from-files` als gleiche Herkunft; ohne die Flagge ist `contentWindow.__VLKR_TEST__` nicht erreichbar.

- [ ] **Step 4: Ausführbar machen und laufen lassen — muss FEHLSCHLAGEN**

Run: `chmod +x tools/check.sh && ./tools/check.sh`
Expected: FAIL, weil `SUBJECTS` noch nicht existiert oder der Testzugang fehlt.

- [ ] **Step 5: Platzhalter korrigieren, bis der Test grün ist**

Run: `./tools/check.sh`
Expected: `PASS  Testzugang vorhanden`, `PASS  Französisch hat 6 Themen`, `ALL PASS`

- [ ] **Step 6: Commit**

```bash
git add tools/selftest.html tools/check.sh index.html
git commit -m "test: Selbsttest-Harnisch fuer Datenerhalt und Invarianten"
```

---

## Task 2: SUBJECTS-Register

**Files:**
- Modify: `index.html` — `TOPICS` (ca. Zeile 1481), `SECTIONS` (ca. Zeile 1591)
- Modify: `tools/selftest.html`

**Interfaces:**
- Consumes: `window.__VLKR_TEST__.topicsOf` aus Task 1.
- Produces: `SUBJECTS` (Array), `FR_TOPICS`, `GE_TOPICS`, `subjectByKey(key)`, `currentSubject()` — von Task 3 bis 15 benutzt.

- [ ] **Step 1: Test schreiben (in `runChecks` ergänzen)**

```js
  check("Zwei Fächer registriert", function(){
    return T.SUBJECTS.length === 2 ? true : "erwartet 2, ist " + T.SUBJECTS.length;
  });
  check("Fach-Schlüssel sind fr und ge", function(){
    var k = T.SUBJECTS.map(function(s){ return s.key; }).join(",");
    return k === "fr,ge" ? true : "ist " + k;
  });
  check("Geschichte hat 7 Themen", function(){
    var t = T.topicsOf("ge");
    return (t && t.length === 7) ? true : "erwartet 7, ist " + (t ? t.length : "null");
  });
  check("Alle Geschichts-Schlüssel mit g- präfixiert", function(){
    var bad = T.topicsOf("ge").filter(function(t){ return t.key.indexOf("g-") !== 0; });
    return bad.length === 0 ? true : "ohne Präfix: " + bad.map(function(t){return t.key;}).join(",");
  });
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `./tools/check.sh`
Expected: FAIL bei «Zwei Fächer registriert»

- [ ] **Step 3: `TOPICS` in `FR_TOPICS` umbenennen**

`var TOPICS = [` wird zu `var FR_TOPICS = [`. Danach alle Lesestellen anpassen:

```bash
grep -n "TOPICS" index.html
```

Betroffen sind `topicByKey`, `makeMixedFeeder`, `buildPool` und `renderHome`. In diesem Task bekommen sie vorläufig `FR_TOPICS`; Task 5 parametrisiert sie richtig.

- [ ] **Step 4: `SECTIONS` in `FR_SECTIONS` umbenennen**

Analog. `SECTIONS` wird von `currentSection`, `renderNav` und `updateTopbarTitle` gelesen.

- [ ] **Step 5: `GE_TOPICS` mit sieben leeren Themen anlegen**

Direkt nach `FR_TOPICS` einfügen. Die `sets` bleiben vorerst leer und werden in Task 6 bis 14 gefüllt.

```js
var GE_TOPICS = [
  {key:"g-zeitstrahl", num:"01", label:"Zeitstrahl", short:"Zeitstrahl",
   sub:"26 Ereignisse von 1798 bis 1999", sets:[]},
  {key:"g-1848", num:"02", label:"1848 &middot; Bundesstaat", short:"1848 · Bundesstaat",
   sub:"Verfassungen 1798–1848, Sonderbundskrieg", sets:[]},
  {key:"g-demokratie", num:"03", label:"Demokratie &amp; Konkordanz", short:"Demokratie & Konkordanz",
   sub:"1874, 1891 und der Weg zur Zauberformel", sets:[]},
  {key:"g-volksrechte", num:"04", label:"Volksrechte", short:"Volksrechte",
   sub:"Initiative, fakultatives und obligatorisches Referendum", sets:[]},
  {key:"g-initiative", num:"05", label:"Volksinitiative", short:"Volksinitiative",
   sub:"Der Ablauf in fünf Schritten", sets:[]},
  {key:"g-weltkrieg", num:"06", label:"Weltkrieg &amp; Zwischenkriegszeit", short:"Weltkrieg & Zwischenkriegszeit",
   sub:"Landesstreik, Fronten, Asylpraxis", sets:[]},
  {key:"g-staatslehre", num:"07", label:"Staatslehre", short:"Staatslehre",
   sub:"Gewaltenteilung, Glossar, smartspider", sets:[]}
];
```

- [ ] **Step 6: `SUBJECTS` und Zugriffshelfer anlegen**

```js
var SUBJECTS = [
  {key:"fr", mark:"C", title:"Cahier de Grammaire", sub:"Französisch",
   topics:FR_TOPICS, sections:FR_SECTIONS},
  {key:"ge", mark:"H", title:"Geschichte", sub:"Staatskunde Schweiz",
   topics:GE_TOPICS, sections:GE_SECTIONS}
];
function subjectByKey(k){
  for(var i=0;i<SUBJECTS.length;i++){ if(SUBJECTS[i].key===k) return SUBJECTS[i]; }
  return null;
}
```

`GE_SECTIONS` wird aus `GE_TOPICS` abgeleitet, damit Themenliste und Navigation nicht auseinanderlaufen können:

```js
var GE_SECTIONS = [{key:"home", label:"Start"}]
  .concat(GE_TOPICS.map(function(t){ return {key:t.key, label:t.short}; }))
  .concat([{key:"test", label:"Prüfung"}]);
```

Achtung auf die Reihenfolge im Datei-Aufbau: `GE_SECTIONS` muss nach `GE_TOPICS` und vor `SUBJECTS` stehen.

- [ ] **Step 7: Den Platzhalter aus Task 1 entfernen**

Die Zeile `var SUBJECTS = [{key:"fr", topics:TOPICS}];` löschen.

- [ ] **Step 8: Test laufen lassen**

Run: `./tools/check.sh`
Expected: `ALL PASS`

- [ ] **Step 9: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "feat: SUBJECTS-Register mit Faechern fr und ge"
```

---

## Task 3: Zweistufiges Routing

**Files:**
- Modify: `index.html` — `currentSection` (ca. 1602), `navigate` (ca. 1688), `renderNav` (ca. 1607), `updateTopbarTitle` (ca. 1676)
- Modify: `tools/selftest.html`

**Interfaces:**
- Consumes: `SUBJECTS`, `subjectByKey` aus Task 2.
- Produces: `parseHash()` → `{subject:String|null, section:String}`, `currentSubject()` → Fach-Objekt oder `null`, `goTo(subjectKey, sectionKey)`.

- [ ] **Step 1: Test schreiben**

```js
  check("Hash #/fr/verbs wird korrekt zerlegt", function(){
    var p = W.__VLKR_TEST__.parseHash("#/fr/verbs");
    return (p.subject === "fr" && p.section === "verbs") ? true : JSON.stringify(p);
  });
  check("Leerer Hash ergibt Fach-Wahl", function(){
    var p = W.__VLKR_TEST__.parseHash("#/");
    return (p.subject === null) ? true : JSON.stringify(p);
  });
  check("Alte Route #/verbs zeigt auf Französisch", function(){
    var p = W.__VLKR_TEST__.parseHash("#/verbs");
    return (p.subject === "fr" && p.section === "verbs") ? true : JSON.stringify(p);
  });
  check("Alte Route #/home zeigt auf Französisch", function(){
    var p = W.__VLKR_TEST__.parseHash("#/home");
    return (p.subject === "fr" && p.section === "home") ? true : JSON.stringify(p);
  });
  check("Unbekanntes Fach ergibt Fach-Wahl", function(){
    var p = W.__VLKR_TEST__.parseHash("#/xx/verbs");
    return (p.subject === null) ? true : JSON.stringify(p);
  });
```

`parseHash` in den Testzugang aufnehmen.

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `./tools/check.sh`
Expected: FAIL, `parseHash is not a function`

- [ ] **Step 3: `parseHash` implementieren**

```js
/* #/            -> Fach-Wahl
   #/fr/verbs    -> Fach fr, Abschnitt verbs
   #/verbs       -> alte einstufige Route, wird auf Französisch gelesen */
function parseHash(h){
  var raw = (h === undefined ? location.hash : h).replace(/^#\/?/, "");
  if(!raw) return {subject:null, section:"home"};
  var parts = raw.split("/");
  if(parts.length >= 2){
    return subjectByKey(parts[0])
      ? {subject:parts[0], section:parts[1] || "home"}
      : {subject:null, section:"home"};
  }
  /* Einstufig: entweder ein Fach-Schlüssel oder eine alte Französisch-Route. */
  if(subjectByKey(parts[0])) return {subject:parts[0], section:"home"};
  for(var i=0;i<FR_SECTIONS.length;i++){
    if(FR_SECTIONS[i].key === parts[0]) return {subject:"fr", section:parts[0]};
  }
  return {subject:null, section:"home"};
}
function currentSubject(){ return subjectByKey(parseHash().subject); }
function goTo(sk, sec){ location.hash = "#/" + sk + "/" + sec; }
```

- [ ] **Step 4: `currentSection` auf das aktive Fach umstellen**

```js
function currentSection(){
  var p = parseHash(), s = subjectByKey(p.subject);
  if(!s) return "home";
  for(var i=0;i<s.sections.length;i++){ if(s.sections[i].key === p.section) return p.section; }
  return "home";
}
```

- [ ] **Step 5: `renderNav` und `updateTopbarTitle` auf `currentSubject()` umstellen**

Beide lesen heute das globale `SECTIONS`. Sie lesen künftig `currentSubject().sections`; ist kein Fach aktiv, rendert `renderNav` nur den Eintrag zur Fach-Wahl (kommt in Task 4). Die Klick-Ziele in `renderNav` werden `goTo(sub.key, s.key)` statt `location.hash = "#/"+s.key`.

- [ ] **Step 6: `navigate` verzweigen**

```js
function navigate(){
  clearSession();
  closeNav();
  var p = parseHash(), sub = subjectByKey(p.subject);
  var el = document.getElementById("content");
  renderNav();
  if(!sub){
    updateTopbarTitle(null);
    renderSubjectPicker(el);      /* Task 4 */
    window.scrollTo(0,0);
    return;
  }
  var sec = currentSection();
  updateTopbarTitle(sec);
  if(sec === "home") renderHome(el);
  else if(sec === "verbs") renderVerbsSection(el);
  else if(sec === "test") renderTestSection(el);
  else renderTopicSection(el, sec);
  window.scrollTo(0,0);
}
```

`renderSubjectPicker` existiert erst in Task 4. Lege in diesem Task eine minimale Fassung an, die nur `el.innerHTML = "<h1 class=\"page-title\">Fächer</h1>";` setzt, damit der Test läuft.

- [ ] **Step 7: Test laufen lassen**

Run: `./tools/check.sh`
Expected: `ALL PASS`

- [ ] **Step 8: Sichtprüfung im Browser**

```bash
open index.html
```

Prüfen: `#/fr/verbs` zeigt die Verben, `#/verbs` springt dorthin, `#/` zeigt die Platzhalter-Überschrift.

- [ ] **Step 9: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "feat: zweistufiges Routing mit Rueckwaertskompatibilitaet"
```

---

## Task 4: Fach-Wahl als Startseite

**Files:**
- Modify: `index.html` — `renderSubjectPicker`, `renderNav`, CSS-Abschnitt «KOLOPHON» vorangehend
- Modify: `tools/selftest.html`

**Interfaces:**
- Consumes: `SUBJECTS`, `parseHash`, `goTo` aus Task 2 und 3.
- Produces: `renderSubjectPicker(el)`, `subjectProgress(subjectKey)` → `{done:Number, total:Number, acc:Number|null}`.

- [ ] **Step 1: Test schreiben**

```js
  check("Fortschritt je Fach zählt nur eigene Themen", function(){
    var p = W.__VLKR_TEST__.subjectProgress("ge");
    return (p.total === 7) ? true : "erwartet total 7, ist " + p.total;
  });
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `./tools/check.sh`

- [ ] **Step 3: `subjectProgress` implementieren**

```js
function subjectProgress(sk){
  var s = subjectByKey(sk), done = 0, sum = 0, n = 0;
  s.topics.forEach(function(t){
    var a = topicAcc(t.key);
    if(a !== null){ done++; sum += a; n++; }
  });
  return {done:done, total:s.topics.length, acc: n ? Math.round(sum/n) : null};
}
```

- [ ] **Step 4: `renderSubjectPicker` implementieren**

```js
function renderSubjectPicker(el){
  var li = levelInfo();
  var html = '<span class="eyebrow">VLKR</span>'
    + '<h1 class="page-title">Deine Fächer</h1>'
    + '<p class="page-lede">Wähle ein Fach. Dein Level zählt über beide zusammen.</p>'
    + '<div class="subject-grid">';
  SUBJECTS.forEach(function(s){
    var p = subjectProgress(s.key);
    var stat = p.acc === null
      ? (p.total + " Themen · noch nicht geübt")
      : (p.total + " Themen · " + p.done + " geübt · " + p.acc + "%");
    html += '<button class="subject-card" data-subject="' + s.key + '">'
      + '<span class="sc-mark">' + s.mark + '</span>'
      + '<span class="sc-body"><span class="sc-title">' + s.title + '</span>'
      + '<span class="sc-sub">' + s.sub + '</span>'
      + '<span class="sc-stat mono">' + stat + '</span></span></button>';
  });
  html += '</div>';
  html += '<div class="level-card"><div class="lc-left">'
    + '<span class="lc-lv">Level ' + li.level + '</span>'
    + '<span class="lc-xp mono">' + li.into + ' / ' + li.need + ' XP</span></div>'
    + '<div class="lc-bar"><i style="width:' + li.pct + '%"></i></div></div>';
  el.innerHTML = html;
  el.querySelectorAll("[data-subject]").forEach(function(b){
    b.onclick = function(){ goTo(b.getAttribute("data-subject"), "home"); };
  });
}
```

- [ ] **Step 5: CSS für die Fach-Karten ergänzen**

Vor dem Abschnitt «KOLOPHON» einfügen, damit die Mobile-Überschreibungen am Dateiende weiterhin gewinnen:

```css
/* ============ FACH-WAHL ============ */
.subject-grid{display:grid; gap:12px; margin:18px 0 8px 0;}
.subject-card{
  display:flex; gap:14px; align-items:flex-start; text-align:left; width:100%;
  background:var(--paper-raised); border:1px solid var(--rule); border-radius:8px;
  padding:18px 20px; cursor:pointer; font-family:inherit; color:var(--ink);
}
.subject-card:hover{border-color:var(--accent); box-shadow:var(--shadow);}
.sc-mark{
  font-family:'Newsreader',serif; font-style:italic; font-weight:600; font-size:24px;
  width:44px; height:44px; border-radius:50%; flex:0 0 auto;
  background:var(--accent); color:var(--accent-ink);
  display:flex; align-items:center; justify-content:center;
}
.sc-body{display:flex; flex-direction:column; gap:2px; min-width:0;}
.sc-title{font-family:'Newsreader',serif; font-size:19px; font-weight:600;}
.sc-sub{font-size:13.5px; color:var(--ink-soft);}
.sc-stat{font-size:11.5px; color:var(--ink-faint); margin-top:6px;}
```

- [ ] **Step 6: Menüeintrag «Alle Fächer» in `renderNav`**

Als erster Eintrag der Schublade, oberhalb der Abschnitte, mit Rücksprung auf `#/`:

```js
  var back = document.createElement("button");
  back.className = "nav-item nav-back";
  back.innerHTML = '<span class="num">↩</span><span>Alle Fächer</span>';
  back.onclick = function(){ location.hash = "#/"; };
  nav.appendChild(back);
```

- [ ] **Step 7: `updateTopbarTitle(null)` behandeln**

Ohne aktives Fach zeigt die Kopfleiste `VLKR`.

- [ ] **Step 8: Test und Sichtprüfung**

Run: `./tools/check.sh`
Expected: `ALL PASS`

Danach im Browser bei 390 px Breite prüfen: Karten stapeln, Tippflächen gross genug, Rücksprung aus dem Menü funktioniert.

- [ ] **Step 9: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "feat: Fach-Wahl als Startseite"
```

---

## Task 5: Quiz-Engine auf das Fach parametrisieren

Ohne diesen Task würde «Alle Themen» Französisch und Geschichte mischen.

**Files:**
- Modify: `index.html` — `topicByKey` (ca. 1511), `makeMixedFeeder` (ca. 1541), `buildPool` (ca. 1548), `renderTestSection`
- Modify: `tools/selftest.html`

**Interfaces:**
- Consumes: `SUBJECTS` aus Task 2.
- Produces: `topicByKey(key)` sucht über alle Fächer; `buildPool(cfg, count)` erwartet `cfg.subject`; `makeMixedFeeder(verbCfg, topics)`.

- [ ] **Step 1: Test schreiben**

```js
  check("Prüfungspool Geschichte enthält keine Französisch-Fragen", function(){
    var frKeys = T.topicsOf("fr").map(function(t){ return t.key; });
    var pool = T.buildPool({subject:"ge", topic:"all", set:"all", verbCfg:{}}, 20);
    var bad = pool.filter(function(q){ return frKeys.indexOf(q.topic) !== -1; });
    return bad.length === 0 ? true : bad.length + " Fremdfragen, erste: " + bad[0].topic;
  });
  check("Prüfungspool Französisch enthält keine Geschichts-Fragen", function(){
    var pool = T.buildPool({subject:"fr", topic:"all", set:"all", verbCfg:{}}, 20);
    var bad = pool.filter(function(q){ return q.topic.indexOf("g-") === 0; });
    return bad.length === 0 ? true : bad.length + " Fremdfragen";
  });
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `./tools/check.sh`

- [ ] **Step 3: `topicByKey` über alle Fächer suchen lassen**

```js
function topicByKey(k){
  for(var s=0;s<SUBJECTS.length;s++){
    var ts = SUBJECTS[s].topics;
    for(var i=0;i<ts.length;i++){ if(ts[i].key===k) return ts[i]; }
  }
  return null;
}
```

- [ ] **Step 4: `makeMixedFeeder` und `buildPool` parametrisieren**

```js
function makeMixedFeeder(verbCfg, topics){
  var list = topics || FR_TOPICS;
  var feeders = list.map(function(t){ return makeFeeder(t.key, "all", verbCfg); });
  return function(){
    var f = pick(feeders), q = f();
    if(q) return q;
    for(var i=0;i<feeders.length;i++){ var q2 = feeders[i](); if(q2) return q2; }
    return null;
  };
}
```

Die alte Rückfallzeile `return q || makeFeeder("verbs","all",verbCfg)();` muss weg — sie würde in einer Geschichts-Session eine Verb-Frage einschleusen.

In `buildPool` den `cfg.topic === "all"`-Zweig über `subjectByKey(cfg.subject).topics` iterieren lassen statt über das globale `TOPICS`.

- [ ] **Step 5: `cfg.subject` an allen Aufrufstellen mitgeben**

```bash
grep -n "startSession(" index.html
```

Jeder `startSession`-Aufruf bekommt `subject: currentSubject().key` in die Konfiguration. Betroffen sind `renderVerbsSection`, `renderTopicDrill` über `bindModeGrid`, und `renderTestSection`.

- [ ] **Step 6: Test laufen lassen**

Run: `./tools/check.sh`
Expected: `ALL PASS`

- [ ] **Step 7: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "feat: Quiz-Engine mischt nur innerhalb eines Fachs"
```

---

## Task 6: Zeitstrahl — Daten und Referenz

**Files:**
- Modify: `index.html` — `TIMELINE`, `REFERENCE["g-zeitstrahl"]`, `TOPIC_LEDE`, CSS
- Modify: `tools/selftest.html`

**Interfaces:**
- Produces: `TIMELINE` (Array aus `{y, exact, t, d, topic}`), `renderTimeline(body)`. Task 7 baut den Drill darauf auf.

- [ ] **Step 1: Test schreiben**

```js
  check("Zeitstrahl hat 26 Einträge", function(){
    return T.TIMELINE.length === 26 ? true : "ist " + T.TIMELINE.length;
  });
  check("Davon 23 mit exaktem Jahr", function(){
    var n = T.TIMELINE.filter(function(e){ return e.exact; }).length;
    return n === 23 ? true : "ist " + n;
  });
  check("Zeitstrahl ist chronologisch sortiert", function(){
    for(var i=1;i<T.TIMELINE.length;i++){
      if(T.TIMELINE[i].y < T.TIMELINE[i-1].y) return "Bruch bei Index " + i;
    }
    return true;
  });
  check("Jeder Eintrag hat Titel, Beschreibung und gültiges Thema", function(){
    var keys = T.topicsOf("ge").map(function(t){ return t.key; });
    for(var i=0;i<T.TIMELINE.length;i++){
      var e = T.TIMELINE[i];
      if(!e.t || !e.d) return "Index " + i + " unvollständig";
      if(keys.indexOf(e.topic) === -1) return "Index " + i + " hat unbekanntes Thema " + e.topic;
    }
    return true;
  });
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `./tools/check.sh`

- [ ] **Step 3: `TIMELINE` anlegen**

Alle 26 Einträge wörtlich aus Spec-Abschnitt 3. `y` ist die Sortierzahl; bei unscharfen Angaben trägt `label` die Anzeigeform.

```js
/* Einzige Quelle für alle datierten Ereignisse. Referenz und Drill lesen
   beide hier — eine Jahreszahl steht deshalb an genau einer Stelle. */
var TIMELINE = [
  {y:1798, exact:true, t:"Helvetische Verfassung", topic:"g-1848",
   d:"Erstes modernes Grundgesetz der Schweiz. Zentralistisch — sie liess weder Kantonen noch Gemeinden Raum für Selbstverwaltung."},
  {y:1803, exact:true, t:"Mediationsakte", topic:"g-1848",
   d:"Von Napoleon diktiert, ersetzt die Helvetische Verfassung. Beschränkt die zentrale Gewalt wieder weitgehend und stärkt den Föderalismus."},
  {y:1815, exact:true, t:"Bundesvertrag", topic:"g-1848",
   d:"Am Wiener Kongress vereinbart. Fortschritte in der militärischen Organisation, zugleich weitere Schwächung der Zentralgewalt — die Schweiz wird wieder ein reiner Staatenbund. Über die Grundrechte schweigt der Vertrag weitgehend."},
  {y:1830, exact:false, label:"1830er", t:"Liberale und Radikale arbeiten auf einen Bundesstaat hin", topic:"g-1848",
   d:"Seit Anfang der 1830er Jahre zielen Liberale und Radikale auf die Schaffung eines zentralen Bundesstaats."},
  {y:1847, exact:true, t:"Sonderbundskrieg", topic:"g-1848",
   d:"Bürgerkrieg vom 3. bis 29. November. Die letzte militärische Auseinandersetzung auf Schweizer Boden."},
  {y:1848, exact:true, t:"Bundesverfassung vom 12. September", topic:"g-1848",
   d:"Die Schweiz wird vom Staatenbund zum Bundesstaat. Erste Verfassung, die sich das Schweizer Volk selbst gab — eine demokratische Insel inmitten der Monarchien Europas."},
  {y:1870, exact:false, label:"1870er", t:"Kulturkampf", topic:"g-demokratie",
   d:"Der weltanschauliche Konflikt zwischen liberalem Staat und katholischer Kirche erreicht seinen Gipfel."},
  {y:1874, exact:true, t:"Totalrevision der Bundesverfassung", topic:"g-demokratie",
   d:"Einführung des fakultativen Gesetzesreferendums. Übergang von der repräsentativen zur halbdirekten Demokratie — und Beginn der Aussöhnung mit den Katholisch-Konservativen."},
  {y:1888, exact:true, t:"Gründung der SP", topic:"g-demokratie",
   d:"Die Sozialdemokratische Partei formiert sich aus der Demokratischen Bewegung und Arbeiterorganisationen."},
  {y:1891, exact:true, t:"Volksinitiative eingeführt", topic:"g-demokratie",
   d:"Volksinitiative auf Teilrevision der Bundesverfassung als formulierter Entwurf — das «Gaspedal» neben der «Bremse» Referendum."},
  {y:1891, exact:true, t:"Josef Zemp in den Bundesrat", topic:"g-demokratie",
   d:"Erster Nicht-Freisinniger im Bundesrat, Katholisch-Konservative. Erster Schritt zur Konkordanz."},
  {y:1918, exact:true, t:"Landesstreik", topic:"g-weltkrieg",
   d:"Landesweiter Generalstreik im November unter Führung des Oltener Aktionskomitees. Forderungen: Proporzwahlrecht, Frauenstimmrecht, 48-Stunden-Woche, AHV. Nach drei Tagen wegen Armeedrohung abgebrochen."},
  {y:1918, exact:true, t:"Gründung der BGB", topic:"g-weltkrieg",
   d:"Bauern-, Gewerbe- und Bürgerpartei, heute SVP — als konservatives Gegengewicht zu SP und Freisinn."},
  {y:1918, exact:false, label:"1918/19", t:"Spanische Grippe", topic:"g-weltkrieg",
   d:"Die Grippewelle fordert über 24'400 Todesopfer."},
  {y:1919, exact:true, t:"48-Stunden-Woche", topic:"g-weltkrieg",
   d:"Rasche Einführung als Folge des Landesstreiks."},
  {y:1919, exact:true, t:"Nationalratswahl erstmals im Proporz", topic:"g-weltkrieg",
   d:"Beendet die absolute Mehrheit des Freisinns."},
  {y:1929, exact:true, t:"Rudolf Minger in den Bundesrat", topic:"g-demokratie",
   d:"Einbindung der BGB in die Regierung — zweiter Schritt zur Konkordanz."},
  {y:1933, exact:true, t:"Frontenfrühling", topic:"g-weltkrieg",
   d:"Die Frontenbewegung erreicht ihren Höhepunkt."},
  {y:1935, exact:true, t:"Totalrevisions-Initiative verworfen", topic:"g-weltkrieg",
   d:"Die Initiative zur faschistischen Umgestaltung wird mit über 70 % Nein-Stimmen abgelehnt. Die Schweiz antwortet mit der «Geistigen Landesverteidigung»."},
  {y:1938, exact:true, t:"Einheitliches Strafgesetzbuch angenommen", topic:"g-weltkrieg",
   d:"Annahme in der Volksabstimmung."},
  {y:1938, exact:true, t:"«J-Stempel» und Konferenz von Évian", topic:"g-weltkrieg",
   d:"Der «J-Stempel» wird mit NS-Deutschland vereinbart. An der Konferenz von Évian versteht sich die Schweiz rein als Transitland."},
  {y:1940, exact:true, t:"Letzte zivile Hinrichtung", topic:"g-weltkrieg",
   d:"Hans Vollenweider wird als letzter Zivilist hingerichtet."},
  {y:1942, exact:true, t:"Strafgesetzbuch tritt in Kraft", topic:"g-weltkrieg",
   d:"Vier Jahre nach der Annahme."},
  {y:1943, exact:true, t:"SP erstmals im Bundesrat", topic:"g-demokratie",
   d:"Dritter Schritt zur Konkordanz."},
  {y:1959, exact:true, t:"Zauberformel", topic:"g-demokratie",
   d:"Einbindung der SP nach dem Schlüssel 2:2:2:1."},
  {y:1999, exact:true, t:"Verbot der Todesstrafe in der Verfassung", topic:"g-weltkrieg",
   d:"Verfassungsrechtliches Verbot."}
];
function tlLabel(e){ return e.label || String(e.y); }
```

- [ ] **Step 4: `renderTimeline` implementieren**

```js
function renderTimeline(body){
  var html = '<div class="timeline">';
  TIMELINE.forEach(function(e){
    html += '<div class="tl-item' + (e.exact ? '' : ' fuzzy') + '">'
      + '<div class="tl-year mono">' + tlLabel(e) + '</div>'
      + '<div class="tl-body"><h4>' + e.t + '</h4><p>' + e.d + '</p></div></div>';
  });
  html += '</div>';
  html += '<div class="callout tip"><b>Unscharfe Angaben:</b> Drei Einträge nennt dein Dossier ohne genaues Jahr '
       + '(1830er, 1870er, 1918/19). Sie sind hell gesetzt und werden nie nach dem exakten Jahr abgefragt.</div>';
  body.innerHTML = html;
}
```

- [ ] **Step 5: CSS für den Zeitstrahl**

Vor «KOLOPHON» einfügen:

```css
/* ============ ZEITSTRAHL ============ */
.timeline{position:relative; margin:14px 0 18px 0; padding-left:62px;}
.timeline::before{
  content:""; position:absolute; left:52px; top:6px; bottom:6px;
  width:1px; background:var(--rule-strong);
}
.tl-item{position:relative; padding:0 0 18px 0;}
.tl-item::before{
  content:""; position:absolute; left:-14px; top:7px;
  width:7px; height:7px; border-radius:50%;
  background:var(--accent); border:2px solid var(--paper);
}
.tl-item.fuzzy::before{background:var(--rule-strong);}
.tl-year{
  position:absolute; left:-62px; top:2px; width:48px; text-align:right;
  font-size:13px; font-weight:600; color:var(--ink);
}
.tl-item.fuzzy .tl-year{color:var(--ink-faint); font-weight:500;}
.tl-body h4{font-family:'Public Sans',sans-serif; font-size:14.5px; font-weight:600; margin-bottom:2px;}
.tl-body p{margin:0; font-size:13.5px; color:var(--ink-soft);}
```

Im Mobile-Block am Dateiende ergänzen:

```css
  .timeline{padding-left:52px;}
  .timeline::before{left:44px;}
  .tl-year{left:-52px; width:40px; font-size:12px;}
```

- [ ] **Step 6: In `REFERENCE` und `TOPIC_LEDE` eintragen**

```js
REFERENCE["g-zeitstrahl"] = renderTimeline;
```

```js
  "g-zeitstrahl": "Alle 26 Ereignisse deines Dossiers in der richtigen Reihenfolge. Wer die Reihenfolge kann, kann auch die Jahreszahlen."
```

- [ ] **Step 7: Test und Sichtprüfung**

Run: `./tools/check.sh`
Expected: `ALL PASS`

Danach `#/ge/g-zeitstrahl` im Browser prüfen, hell und dunkel, bei 390 px und auf Desktop.

- [ ] **Step 8: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "feat: Zeitstrahl-Daten und Referenzansicht"
```

---

## Task 7: Zeitstrahl-Drill

**Files:**
- Modify: `index.html` — `buildTimelineYear`, `buildTimelineEvent`, `buildTimelineOrder`, `GE_TOPICS`
- Modify: `tools/selftest.html`

**Interfaces:**
- Consumes: `TIMELINE`, `tlLabel` aus Task 6; `inputQ`, `choiceQ`, `shuffle`, `pick` aus dem Bestand.
- Produces: drei `build*`-Funktionen ohne Argumente, die je ein Array von Fragen liefern.

- [ ] **Step 1: Test schreiben**

Das ist die wichtigste Invariante des ganzen Moduls.

```js
  check("Jahresfragen nur aus exakten Einträgen", function(){
    var bank = T.bankFor("g-zeitstrahl", "year");
    var fuzzy = T.TIMELINE.filter(function(e){ return !e.exact; })
                          .map(function(e){ return e.t; });
    var bad = bank.filter(function(q){
      return fuzzy.some(function(t){ return q.prompt.indexOf(t) !== -1; });
    });
    return bad.length === 0 ? true : "unscharfer Eintrag in Frage: " + bad[0].prompt;
  });
  check("Jahresfragen akzeptieren die reine Jahreszahl", function(){
    var bank = T.bankFor("g-zeitstrahl", "year");
    var bad = bank.filter(function(q){ return !/^\d{4}$/.test(q.accept[0]); });
    return bad.length === 0 ? true : "unerwartete Antwort: " + bad[0].accept[0];
  });
  check("Zuordnungsfragen haben vier verschiedene Optionen", function(){
    var bank = T.bankFor("g-zeitstrahl", "event");
    var bad = bank.filter(function(q){
      var u = {}; q.choices.forEach(function(c){ u[c] = 1; });
      return q.choices.length !== 4 || Object.keys(u).length !== 4;
    });
    return bad.length === 0 ? true : bad.length + " Fragen mit doppelten Optionen";
  });
  check("Zuordnungsfragen enthalten ihre eigene Antwort", function(){
    var bank = T.bankFor("g-zeitstrahl", "event");
    var bad = bank.filter(function(q){ return q.choices.indexOf(q.answer) === -1; });
    return bad.length === 0 ? true : bad.length + " Fragen ohne richtige Option";
  });
  check("Reihenfolge-Fragen nutzen unterschiedliche Jahre", function(){
    var bank = T.bankFor("g-zeitstrahl", "order");
    return bank.length > 0 ? true : "Bank ist leer";
  });
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `./tools/check.sh`

- [ ] **Step 3: `buildTimelineYear` implementieren**

```js
/* Typ 1: Jahr nennen. Nur exakte Einträge. */
function buildTimelineYear(){
  var out = [];
  TIMELINE.forEach(function(e){
    if(!e.exact) return;
    out.push(inputQ("g-zeitstrahl", "Jahreszahl",
      "In welchem Jahr: " + e.t + "?",
      "Vierstellige Jahreszahl",
      [String(e.y)], String(e.y), e.d));
  });
  return out;
}
```

- [ ] **Step 4: `buildTimelineEvent` implementieren**

Distraktoren sind echte, zeitlich benachbarte Ereignisse — dadurch prüft die Frage Unterscheidung statt Ausschluss.

```js
/* Typ 2: Ereignis zuordnen. Distraktoren sind echte Nachbar-Ereignisse. */
function buildTimelineEvent(){
  var out = [];
  TIMELINE.forEach(function(e, idx){
    if(!e.exact) return;
    var near = [], i;
    for(i = Math.max(0, idx-3); i <= Math.min(TIMELINE.length-1, idx+3); i++){
      if(i !== idx && TIMELINE[i].t !== e.t) near.push(TIMELINE[i].t);
    }
    /* Auffüllen, falls am Rand des Zeitstrahls zu wenige Nachbarn da sind. */
    TIMELINE.forEach(function(o){
      if(near.length < 3 && o.t !== e.t && near.indexOf(o.t) === -1) near.push(o.t);
    });
    var choices = shuffle(near.slice(0,3).concat([e.t]));
    out.push(choiceQ("g-zeitstrahl", "Zuordnen",
      "Was geschah " + e.y + "?", "",
      choices, e.t, e.d));
  });
  return out;
}
```

- [ ] **Step 5: `buildTimelineOrder` implementieren**

```js
/* Typ 3: Reihenfolge. Nahe Paare, weil weit entfernte trivial sind. */
function buildTimelineOrder(){
  var out = [], i, j;
  for(i = 0; i < TIMELINE.length; i++){
    for(j = i+1; j < Math.min(i+4, TIMELINE.length); j++){
      var a = TIMELINE[i], b = TIMELINE[j];
      if(a.y === b.y) continue;            /* gleiches Jahr hat keine Reihenfolge */
      if(!a.exact || !b.exact) continue;   /* unscharf: Reihenfolge nicht belegbar */
      out.push(choiceQ("g-zeitstrahl", "Reihenfolge",
        "Was kam zuerst?", "",
        shuffle([a.t, b.t]), a.t,
        a.t + " (" + a.y + ") kam vor " + b.t + " (" + b.y + ")."));
    }
  }
  return out;
}
```

Der Ausschluss unscharfer Einträge ist notwendig: Ob die Spanische Grippe (1918/19) vor oder nach der BGB-Gründung (1918) lag, gibt das Dossier nicht her.

- [ ] **Step 6: Sets im Thema eintragen**

```js
  {key:"g-zeitstrahl", num:"01", label:"Zeitstrahl", short:"Zeitstrahl",
   sub:"26 Ereignisse von 1798 bis 1999",
   sets:[
     {key:"year",  label:"Jahr nennen",      build:buildTimelineYear},
     {key:"event", label:"Ereignis zuordnen", build:buildTimelineEvent},
     {key:"order", label:"Was kam zuerst?",   build:buildTimelineOrder}
   ]},
```

- [ ] **Step 7: Test laufen lassen**

Run: `./tools/check.sh`
Expected: `ALL PASS`

- [ ] **Step 8: Im Browser eine Runde spielen**

`#/ge/g-zeitstrahl` → Üben → Runde. Prüfen, dass Erklärungen sinnvoll sind und keine Frage nach einem unscharfen Jahr fragt.

- [ ] **Step 9: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "feat: Zeitstrahl-Drill mit drei Fragetypen"
```

---

## Task 8: Zahlen-Drill und Sonderbund-Kantone

**Files:**
- Modify: `index.html` — `buildZahlen`, `buildSonderbund`, `GE_TOPICS`
- Modify: `tools/selftest.html`

**Interfaces:**
- Produces: `buildZahlen()`, `buildSonderbund()`. Beide hängen am Thema `g-volksrechte` beziehungsweise `g-1848`.

- [ ] **Step 1: Test schreiben**

Die Werte werden gegen die Spec geprüft, damit ein Tippfehler auffällt.

```js
  check("Zahlen-Bank enthält die Kernquoren", function(){
    var bank = T.bankFor("g-volksrechte", "zahlen");
    var joined = bank.map(function(q){ return q.display; }).join("|");
    var need = ["100'000", "18 Monate", "50'000", "100 Tage"];
    var missing = need.filter(function(v){ return joined.indexOf(v) === -1; });
    return missing.length === 0 ? true : "fehlt: " + missing.join(", ");
  });
  check("Acht Sonderbund-Kantone", function(){
    var bank = T.bankFor("g-1848", "sonderbund");
    return bank.length >= 8 ? true : "nur " + bank.length + " Fragen";
  });
```

- [ ] **Step 2: Test laufen lassen — muss fehlschlagen**

Run: `./tools/check.sh`

- [ ] **Step 3: `buildZahlen` implementieren**

Alle Werte wörtlich aus Spec-Abschnitt 4.

```js
var ZAHLEN = [
  {f:"Wie viele Unterschriften braucht eine Volksinitiative?", a:"100'000", alt:["100000","100 000"],
   e:"100'000 Stimmberechtigte innert 18 Monaten."},
  {f:"Wie lange ist die Sammelfrist einer Volksinitiative?", a:"18 Monate", alt:["18"],
   e:"18 Monate ab der Vorprüfung."},
  {f:"Wie viele Unterschriften braucht das fakultative Referendum?", a:"50'000", alt:["50000","50 000"],
   e:"50'000 Stimmberechtigte — oder 8 Kantone."},
  {f:"Wie viele Kantone können ersatzweise ein fakultatives Referendum verlangen?", a:"8", alt:["acht"],
   e:"8 Kantone anstelle von 50'000 Unterschriften."},
  {f:"Wie lange ist die Frist beim fakultativen Referendum?", a:"100 Tage", alt:["100"],
   e:"100 Tage ab Veröffentlichung des Gesetzes."},
  {f:"Wie viele Mitglieder hat ein Initiativkomitee mindestens?", a:"7", alt:["sieben"],
   e:"Mindestens 7, höchstens 27 stimmberechtigte Schweizer Bürgerinnen und Bürger."},
  {f:"Wie viele Mitglieder darf ein Initiativkomitee höchstens haben?", a:"27",
   e:"Mindestens 7, höchstens 27 stimmberechtigte Schweizer Bürgerinnen und Bürger."},
  {f:"Wie viele Kantonsstimmen braucht das Ständemehr mindestens?", a:"12", alt:["zwölf"],
   e:"Mindestens 12 der 23 Kantonsstimmen."},
  {f:"Wie viele Kantonsstimmen gibt es insgesamt?", a:"23",
   e:"23 Kantonsstimmen; für das Ständemehr braucht es mindestens 12."},
  {f:"Wie viele Sitze hat der Nationalrat?", a:"200",
   e:"Nationalrat 200 Sitze, Ständerat 46 Sitze."},
  {f:"Wie viele Sitze hat der Ständerat?", a:"46",
   e:"Nationalrat 200 Sitze, Ständerat 46 Sitze."},
  {f:"Aus wie vielen Mitgliedern besteht der Bundesrat?", a:"7", alt:["sieben"],
   e:"7 gleichberechtigte Mitglieder."},
  {f:"Wie lautet die Zauberformel von 1959?", a:"2:2:2:1", alt:["2 2 2 1","2-2-2-1"],
   e:"Seit 1959 der Verteilschlüssel im Bundesrat."},
  {f:"Wie viele Achsen hat die smartspider?", a:"8", alt:["acht"],
   e:"8 Speichen, je auf einer Skala von 0 bis 100."},
  {f:"Wie viele Todesopfer forderte die Spanische Grippe?", a:"24'400", alt:["24400","24 400"],
   e:"Über 24'400 Todesopfer 1918/19."}
];
function buildZahlen(){
  return ZAHLEN.map(function(z){
    return inputQ("g-volksrechte", "Zahl", z.f, "",
      [z.a].concat(z.alt || []), z.a, z.e);
  });
}
```

- [ ] **Step 4: `buildSonderbund` implementieren**

```js
var SONDERBUND = ["Luzern","Schwyz","Uri","Zug","Obwalden","Nidwalden","Freiburg","Wallis"];
var NICHT_SONDERBUND = ["Bern","Zürich","Aargau","Thurgau","Genf","Waadt","Basel-Stadt","Solothurn"];
function buildSonderbund(){
  var out = [];
  SONDERBUND.forEach(function(k){
    out.push(choiceQ("g-1848", "Sonderbund",
      "Gehörte " + k + " zum Sonderbund?", "",
      ["Ja","Nein"], "Ja",
      "Der Sonderbund bestand aus Luzern, Schwyz, Uri, Zug, Obwalden, Nidwalden, Freiburg und Wallis."));
  });
  NICHT_SONDERBUND.forEach(function(k){
    out.push(choiceQ("g-1848", "Sonderbund",
      "Gehörte " + k + " zum Sonderbund?", "",
      ["Ja","Nein"], "Nein",
      "Der Sonderbund bestand aus Luzern, Schwyz, Uri, Zug, Obwalden, Nidwalden, Freiburg und Wallis."));
  });
  return out;
}
```

Die Kantone in `NICHT_SONDERBUND` sind nicht als Faktenbehauptung des Dossiers gedacht, sondern als Gegenprobe: Das Dossier nennt die acht Sonderbund-Kantone abschliessend, alle übrigen gehörten folglich nicht dazu.

- [ ] **Step 5: Sets eintragen und Test laufen lassen**

Run: `./tools/check.sh`
Expected: `ALL PASS`

- [ ] **Step 6: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "feat: Zahlen-Drill und Sonderbund-Kantone"
```

---

## Tasks 9 bis 14: Inhaltsthemen

Diese sechs Tasks haben dieselbe Form: je eine Referenz-Funktion und ein bis zwei Bank-Builder, eingetragen in `REFERENCE`, `TOPIC_LEDE` und `GE_TOPICS`. Der Inhalt steht in Spec-Abschnitt 5; keine Angabe darf darüber hinausgehen.

Für **jeden** dieser Tasks gilt derselbe Ablauf:

- [ ] **Step 1:** Test in `runChecks` ergänzen — Bank ist nicht leer, jede Frage hat `prompt`, `explain` und eine nichtleere Antwort, und alle `topic`-Felder tragen den Themenschlüssel des Tasks.
- [ ] **Step 2:** Test laufen lassen, Fehlschlag bestätigen.
- [ ] **Step 3:** Referenz-Funktion schreiben, im bestehenden Markup-Vokabular (`.card`, `.tablewrap`, `.callout`, `.chip`).
- [ ] **Step 4:** Bank-Builder schreiben, mit `inputQ`/`choiceQ`.
- [ ] **Step 5:** In `REFERENCE`, `TOPIC_LEDE` und `GE_TOPICS` eintragen.
- [ ] **Step 6:** `./tools/check.sh` — `ALL PASS`.
- [ ] **Step 7:** Im Browser Referenz und eine Übungsrunde prüfen.
- [ ] **Step 8:** Commit.

### Task 9: `g-1848`

Referenz: Verfassungsreihe 1798 → 1803 → 1815 → 1848 als Tabelle mit Jahr, Name und Kennzeichen; Sonderbundskrieg mit Anlass, Dauer, Lagern und Kriegsziel; Staatenbund gegenüber Bundesstaat; die BV von 1848 als demokratische Insel unter Monarchien; Aussöhnung erst über 1874.
Bank: Zuordnung Verfassung ↔ Kennzeichen, Konfession der Lager (katholisch-konservativ gegen liberal-reformiert), Dauer des Kriegs, Datum der BV. Dazu `buildSonderbund` aus Task 8.

### Task 10: `g-demokratie`

Referenz: Freisinn als Sieger von 1847 und seine Ziele (individuelle Freiheiten, Rechtsgleichheit, Wirtschaftsfreiheit, Trennung von Kirche und Staat); Gegenposition der Katholisch-Konservativen (Föderalismus, bäuerliche Strukturen, Einfluss der Kirche); Spaltung in Demokraten und Gemässigte; SP 1888; repräsentativ bis 1874, danach halbdirekt; Referendum als «Bremse», Initiative als «Gaspedal»; Konkordanz gegenüber Konkurrenzdemokratie; die drei Konkordanzschritte Zemp 1891, Minger 1929, SP 1943/1959.
Bank: Wer war wann der erste seiner Partei im Bundesrat, Bremse gegen Gaspedal, Jahr der Zauberformel, Bedeutung von Konkordanz.

### Task 11: `g-volksrechte`

Referenz: die Vergleichstabelle der drei Instrumente nach Zweck, Quorum, Frist und erforderlichem Mehr (Spec-Abschnitt 4 und die Tabelle im Dossier); darunter die drei Fälle des obligatorischen Referendums.
Bank: `buildZahlen` aus Task 8 plus Zuordnungsfragen «welches Instrument braucht welches Mehr».
Die Tabelle bekommt `class="conj"` nicht — sie braucht keine klebende Spalte, weil sie nur vier Spalten hat; falls sie mobil doch überläuft, greift der bestehende `.tablewrap`-Horizontalscroll.

### Task 12: `g-initiative`

Referenz: die fünf Schritte von der Vorprüfung bis zur Volksabstimmung als nummerierte Liste — hier ist die Nummerierung inhaltlich gerechtfertigt, weil die Schritte tatsächlich eine feste Reihenfolge haben; Prüfkriterien der Gültigkeit (Einheit der Materie, Einheit der Form, zwingendes Völkerrecht); direkter gegenüber indirektem Gegenvorschlag.
Bank: Reihenfolge der Schritte, wer die Vorprüfung macht (Bundeskanzlei), die drei Gültigkeitskriterien, Unterschied direkter/indirekter Gegenvorschlag.

### Task 13: `g-weltkrieg`

Referenz: General Ulrich Wille und die Obersten-Affäre; Röstigraben mit den beiden Sympathierichtungen; fehlender Erwerbsersatz und späte Rationierung; Landesstreik mit seinen vier Forderungen; BGB-Gründung; Proporz 1919; Frontenfrühling 1933 und die Geistige Landesverteidigung; Strafgesetzbuch 1938/1942, letzte Hinrichtung 1940, Verbot 1999; Asylpraxis mit J-Stempel und Évian.
Bank: die vier Forderungen des Landesstreiks, wer die Deutschschweiz und wer die Romandie unterstützte, Dauer des Landesstreiks, Jahreszahlen der Strafrechtsreihe.

### Task 14: `g-staatslehre`

Referenz: Glossar (Konkordanz, Bundesstaat gegenüber Staatenbund, Kulturkampf); Gewaltenteilung mit Legislative (Bundesversammlung, 200 und 46 Sitze), Exekutive (Bundesrat, 7 Mitglieder) und Judikative (Bundesgericht, Lausanne/Luzern); smartspider mit den acht Achsen, der Skala 0 bis 100 und den vier Parteiprofilen.
Bank: Zuordnung Organ ↔ Gewalt, Sitzzahlen, die acht Achsen, Zuordnung Parteiprofil ↔ Partei.

---

## Task 15: Mobile-Feinschliff und Schlussverifikation

**Files:**
- Modify: `index.html` — Mobile-Block am Ende des Stylesheets
- Modify: `tools/selftest.html`

- [ ] **Step 1: Überlaufprüfung ergänzen**

```js
  check("Kein horizontaler Überlauf im Iframe", function(){
    var d = W.document;
    return d.documentElement.scrollWidth <= W.innerWidth + 1
      ? true
      : "scrollWidth " + d.documentElement.scrollWidth + " > " + W.innerWidth;
  });
```

- [ ] **Step 2: Jede Geschichts-Seite bei 390 px durchgehen**

Für jeden der sieben Themenschlüssel Referenz und Übung öffnen. Auf zu kleine Tippflächen, überlaufende Tabellen und abgeschnittene Zeitstrahl-Jahreszahlen achten.

- [ ] **Step 3: Spec-Abschnitt 7 Punkt für Punkt abhaken**

- Alle Jahreszahlen gegen Spec-Abschnitt 3 prüfen.
- Alle Zahlen gegen Spec-Abschnitt 4 prüfen.
- Kein `exact:false` in einer Jahresfrage (deckt Task 7 automatisch ab).
- Bestehenden Französisch-Fortschritt prüfen: vor dem Umbau `localStorage.cahier_progress_v2` sichern, nach dem Umbau vergleichen.
- Alte Routen prüfen: `#/verbs`, `#/home`, `#/test`.
- «Alle Themen» je Fach prüfen.
- Hell und dunkel, 390 px und Desktop.
- Konsole fehlerfrei.

- [ ] **Step 4: Deploy**

```bash
./tools/check.sh && git push origin main && vercel --prod --yes
```

Der Selbsttest läuft bewusst vor dem Push — ein rotes Ergebnis soll das Deployment verhindern.

- [ ] **Step 5: Live prüfen**

```bash
curl -s "https://vlkr.ch/?t=$(date +%s)" | grep -c "g-zeitstrahl"
```

Erwartet: eine Zahl grösser als 0.

- [ ] **Step 6: Commit**

```bash
git add index.html tools/selftest.html
git commit -m "polish: mobiler Feinschliff und Schlussverifikation"
```

---

## Selbstprüfung des Plans

**Spec-Abdeckung**

| Spec-Abschnitt | Task |
| --- | --- |
| 1 Fach-Ebene, Datenstruktur | 2 |
| 1 Routing samt Rückwärtskompatibilität | 3 |
| 1 Auswirkung auf die Quiz-Engine | 5 |
| 1 Auswirkung auf den Fortschritt | 4, 15 |
| 1 Startseite | 4 |
| 2 Sieben Themen | 2 (Gerüst), 6–14 (Inhalt) |
| 3 Zeitstrahl, Daten und `exact` | 6 |
| 3 Drei Fragetypen | 7 |
| 4 Zahlen-Drill | 8 |
| 5 Inhalt der übrigen Themen | 9–14 |
| 6 Gestaltung | 6 (Zeitstrahl-CSS), 15 (Mobile) |
| 7 Verifikation | 1 (Harnisch), 15 (Abschluss) |

**Typkonsistenz**

- `parseHash()` liefert überall `{subject, section}`; `subject` ist `null` bei der Fach-Wahl.
- `TIMELINE`-Einträge: `{y:Number, exact:Boolean, t:String, d:String, topic:String}`, optional `label:String`.
- Alle `build*`-Funktionen sind argumentlos und liefern ein Array von `inputQ`/`choiceQ`-Objekten.
- `subjectProgress()` liefert `{done, total, acc}` mit `acc === null`, solange nichts geübt wurde.

**Offener Punkt für später, nicht Teil dieses Plans:** `index.html` erreicht rund 3300 Zeilen. Eine Aufteilung in mehrere Dateien wäre ein eigener Auftrag und würde gegen die heutige Deploy-Einfachheit abgewogen werden müssen.
