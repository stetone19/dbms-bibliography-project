[![🇮🇹 Italiano](https://img.shields.io/badge/README-Italiano-green?style=flat-square)](README_IT.md)
[![🇬🇧 English](https://img.shields.io/badge/README-English-blue?style=flat-square)](README.md)

# 📚 Academic Bibliography Database

> Relational database for managing an academic bibliography, designed and implemented as part of the *Laboratorio di Basi di Dati* course (a.a. 2025–2026) at the **Università degli Studi di Udine**.

---

## 📌 Project Overview

This project covers the full database design pipeline for an academic bibliography system focused on the **Triveneto region** (Friuli-Venezia Giulia, Veneto, Trentino-Alto Adige). The scope includes:

- **Requirements analysis** with glossary and operational requirements
- **Conceptual design** — Entity-Relationship schema (bottom-up, 4 iterative revisions)
- **Logical design** — redundancy analysis, ER restructuring, relational schema
- **Physical design** — SQL DDL, data population, triggers, complex queries

The database manages publications (journal articles, conference papers, books, theses), authors, affiliations, publishers, and bibliographic citations with full referential integrity.

---

## 🗄️ Database Schema

### Tables

| Table | Description |
|---|---|
| `pubblicazioni` | Base table for all publications (code, title, year, pages, citation count) |
| `articoli` | Journal and conference articles (type, volume, venue, pages) |
| `libri` | Books (ISBN, publisher) |
| `tesi` | Theses (topic, university affiliation) |
| `autori` | Authors (name, surname, email, website) |
| `affiliazioni` | Affiliations — universities and research institutes |
| `editori` | Publishers (name, address) |
| `citazioni` | Bibliographic citations (citing ↔ cited publication) |
| `pubblicazioneautore` | Many-to-many: publications ↔ authors |
| `autoreaffiliazione` | Many-to-many: authors ↔ affiliations |

### Key Design Decisions

- `Articolo` is discriminated by a `tipo` field (`'Rivista'` / `'Conferenza'`), with mutually exclusive attributes enforced by trigger.
- `Affiliazione` uses a `tipo` field (`'Università'` / `'Ente di ricerca'`) to subsume the specialization hierarchy, keeping the link to theses semantically clean.
- `NumeroCitazioni` is kept as a **redundant derived attribute** on `pubblicazioni` — retained after a cost-benefit analysis (860 vs 10,740 access units/day) to optimise the high-frequency read operation (OP1: ~500 times/day).
- The total coverage constraint (every publication must be exactly one of Articolo / Libro / Tesi) is enforced via exclusivity triggers.

---

## ⚙️ Triggers

### Required triggers

| Trigger | Function | Event |
|---|---|---|
| `trg_ins_CIT` | Increments `ncitazioni`; checks: no self-citation, no future citation, no direct cycle | `BEFORE INSERT` on `citazioni` |
| `trg_rim_CIT` | Decrements `ncitazioni` | `BEFORE DELETE` on `citazioni` |
| `trg_upd_CIT` | Blocks any update on citations (delete + re-insert instead) | `BEFORE UPDATE` on `citazioni` |
| `trg_TESI` | Ensures the thesis affiliation is a University and is linked to at least one of the thesis authors | `BEFORE INSERT OR UPDATE` on `tesi` |

### Additional integrity triggers

| Trigger | Description |
|---|---|
| `trigger_libro` | Exclusivity check (not already an Articolo/Tesi) + publisher existence |
| `trigger_articolo` | Exclusivity check + attribute consistency per type (Conferenza/Rivista) |
| `trigger_pubb_autore` | Author and publication existence check |
| `trigger_aut_aff` | Author and affiliation existence check |

### Note on circular citations

Direct cycles (A cites B, B cites A) between same-year publications are detected and blocked. Longer cycles (3+ nodes, same year) are deliberately **not** tracked, as a DFS traversal over 100k publications and 2M citation edges at each insert would be prohibitively expensive — a trade-off explicitly analysed in the project report.

---

## 🔍 Queries

| Query | Description |
|---|---|
| **Q1** | Author with the highest publication count for each affiliation |
| **Q2** | Pairs of authors who have **always and only** co-authored together |
| **Q3** | Authors who have never published with a co-author from a different affiliation |
| **Q4** | Authors whose publications all accumulated ≥ 5 citations within 2 years of publication (dynamic count — the derived attribute cannot be used here) |

---

## 🚀 Setup

### Requirements

- PostgreSQL 14+
- `psql` CLI or any PostgreSQL client (e.g., pgAdmin, DBeaver)

### Run

```bash
# 1. Create the database
createdb bibliography

# 2. Run the script (creates tables, triggers, populates data, runs queries)
psql -d bibliography -f bibliografia_db.sql
```

> All DDL, triggers, data inserts and queries are in a single script for reproducibility.

---

## 📁 Repository Structure

```
dbms-bibliography-project/
├── latex
├── src
├── bibliografia_db.sql       # Full SQL script (DDL + triggers + data + queries)
└── README.md
```

---

## 👥 Authors

| Name | Student ID | Email |
|---|---|---|
| Federico Del Pup | 167087 | federico.delpup04@gmail.com |
| Luigi Pascu | 166851 | luigipascu04@gmail.com |
| Matteo Passador | 168215 | matteo.passador19@gmail.com |
| Stefano Toneguzzo | 168579 | stefano.toneguzzo04@gmail.com |

---

## 🎓 Academic Context

**Course:** Laboratorio di Basi di Dati — a.a. 2025/2026  
**Instructor:** Angelo Montanari, Luca Geatti, Nicola Saccomanno  
**Degree programme:** Computer Science Bachelor Degree
**University:** Università degli Studi di Udine
