[![🇮🇹 Italiano](https://img.shields.io/badge/README-Italiano-green?style=flat-square)](README_IT.md)
[![🇬🇧 English](https://img.shields.io/badge/README-English-blue?style=flat-square)](README.md)

# 📚 Database Bibliografico Accademico

> Base di dati relazionale per la gestione di una bibliografia accademica, progettata e implementata nell'ambito del corso di *Laboratorio di Basi di Dati* (a.a. 2025–2026) presso l'**Università degli Studi di Udine**.

---

## 📌 Descrizione del progetto

Il progetto copre l'intero ciclo di progettazione di una base di dati per una bibliografia accademica circoscritta al contesto regionale del **Triveneto** (Friuli-Venezia Giulia, Veneto, Trentino-Alto Adige). Le fasi sviluppate sono:

- **Analisi dei requisiti** — glossario e requisiti operazionali
- **Progettazione concettuale** — schema Entità-Relazione (approccio bottom-up, 4 revisioni iterative)
- **Progettazione logica** — analisi delle ridondanze, ristrutturazione dello schema ER, schema relazionale
- **Progettazione fisica** — DDL SQL, popolamento, trigger, query complesse

La base di dati gestisce pubblicazioni (articoli su rivista, articoli per conferenza, libri, tesi), autori, affiliazioni, editori e citazioni bibliografiche, con piena integrità referenziale.

---

## 🗄️ Schema della base di dati

### Tabelle

| Tabella | Descrizione |
|---|---|
| `pubblicazioni` | Tabella base per tutte le pubblicazioni (codice, titolo, anno, pagine, numero citazioni) |
| `articoli` | Articoli su rivista e per conferenza (tipo, volume, luogo, pagine) |
| `libri` | Libri (ISBN, editore) |
| `tesi` | Tesi di laurea (argomento, affiliazione universitaria) |
| `autori` | Autori (nome, cognome, email, sito web) |
| `affiliazioni` | Affiliazioni — università ed enti di ricerca |
| `editori` | Editori (nome, indirizzo) |
| `citazioni` | Citazioni bibliografiche (pubblicazione citante ↔ pubblicazione citata) |
| `pubblicazioneautore` | Relazione molti-a-molti: pubblicazioni ↔ autori |
| `autoreaffiliazione` | Relazione molti-a-molti: autori ↔ affiliazioni |

### Principali scelte progettuali

- `Articolo` è discriminato dall'attributo `tipo` (`'Rivista'` / `'Conferenza'`), con attributi mutuamente esclusivi imposti tramite trigger.
- `Affiliazione` utilizza un attributo `tipo` (`'Università'` / `'Ente di ricerca'`) per accorpare la gerarchia di specializzazione, mantenendo il collegamento semantico con le tesi.
- `NumeroCitazioni` è mantenuto come **attributo derivato ridondante** su `pubblicazioni` — conservato a seguito di un'analisi costi-benefici (860 vs 10.740 unità di accesso al giorno) per ottimizzare l'operazione di lettura ad alta frequenza (OP1: ~500 volte/giorno).
- Il vincolo di copertura totale (ogni pubblicazione deve essere esattamente uno tra Articolo / Libro / Tesi) è imposto tramite trigger di esclusività.

---

## ⚙️ Trigger

### Trigger richiesti

| Trigger | Funzione | Evento |
|---|---|---|
| `trg_ins_CIT` | Incrementa `ncitazioni`; controlli: no autocitazione, no citazione futura, no ciclo diretto | `BEFORE INSERT` su `citazioni` |
| `trg_rim_CIT` | Decrementa `ncitazioni` | `BEFORE DELETE` su `citazioni` |
| `trg_upd_CIT` | Blocca qualsiasi aggiornamento sulle citazioni (eliminare e reinserire) | `BEFORE UPDATE` su `citazioni` |
| `trg_TESI` | Verifica che l'affiliazione della tesi sia un'università e che sia collegata ad almeno uno degli autori | `BEFORE INSERT OR UPDATE` su `tesi` |

### Trigger aggiuntivi per completezza

| Trigger | Descrizione |
|---|---|
| `trigger_libro` | Controllo esclusività (non già presente come Articolo/Tesi) + esistenza dell'editore |
| `trigger_articolo` | Controllo esclusività + coerenza attributi per tipo (Conferenza/Rivista) |
| `trigger_pubb_autore` | Controllo esistenza autore e pubblicazione |
| `trigger_aut_aff` | Controllo esistenza autore e affiliazione |

### Nota sulle citazioni circolari

I cicli diretti (A cita B, B cita A) tra pubblicazioni dello stesso anno vengono rilevati e bloccati. I cicli più lunghi (3+ nodi, stesso anno) sono deliberatamente **non gestiti**: una visita DFS su 100k pubblicazioni e 2M archi di citazione ad ogni inserimento sarebbe eccessivamente onerosa — un trade-off esplicitamente analizzato nella relazione.

---

## 🔍 Query

| Query | Descrizione |
|---|---|
| **Q1** | Autore con il maggior numero di pubblicazioni per ogni affiliazione |
| **Q2** | Coppie di autori che hanno pubblicato **sempre e solo** insieme |
| **Q3** | Autori che non hanno mai co-firmato pubblicazioni con autori di affiliazioni diverse dalla propria |
| **Q4** | Autori le cui pubblicazioni hanno tutte accumulato ≥ 5 citazioni entro 2 anni dalla pubblicazione (conteggio dinamico — l'attributo derivato non è utilizzabile in questo caso) |

---

## 🚀 Esecuzione

### Requisiti

- PostgreSQL 14+
- `psql` da riga di comando o un client PostgreSQL (es. pgAdmin, DBeaver)

### Istruzioni

```bash
# 1. Crea il database
createdb bibliography

# 2. Esegui lo script (crea tabelle, trigger, popola i dati, esegue le query)
psql -d bibliography -f bibliografia_db.sql
```

> Tutto il DDL, i trigger, i dati di popolamento e le query sono contenuti in un unico script per garantire la riproducibilità.

---

## 📁 Struttura del repository



```
dbms-bibliography-project/
├── latex
├── src       
├── sql       # Full SQL script (DDL + triggers + data + queries)
├── README.md
└── README_IT.md
```

---

## 👥 Autori

| Nome | Matricola 
|---|---|
| Federico Del Pup | 167087 
| Luigi Pascu | 166851 
| Matteo Passador | 168215 
| Stefano Toneguzzo | 168579 

---

## 🎓 Contesto accademico

**Corso:** Laboratorio di Basi di Dati — a.a. 2025/2026  
**Docente:** Luca Geatti  
**Corso di laurea:** Corso di Laurea in Informatica  
**Università:** Università degli Studi di Udine  
**Gruppo:** Gruppo 9
