# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Grap** is a Perl-based web scraping system for collecting store location data from Taiwan convenience store chains and restaurant franchises (7-Eleven, FamilyMart, Hi-Life, OK Mart, WuTau, BuyGood, JengJong). Scraped data is normalized into CSV files and uploaded to a centralized API backed by PostgreSQL.

## Common Commands

```bash
# Run a store scraper (from within the store's directory)
cd 711/ && perl grap_711.pl
cd FamilyMart/ && perl familymart.pl
cd HiLife/ && perl hilife_v3.pl

# Merge city-level CSVs into a single file
perl merge.pl

# Upload merged CSV to API
perl upload/app/upload_csv.pl -f <csv_file> -c upload/app/config.json

# Install Perl dependencies
cpan LWP::UserAgent HTML::TreeBuilder::XPath URI::Escape HTTP::Cookies JSON DBI DBD::Pg Getopt::Long

# Install Python dependencies (for menu/OCR processing)
pip install -r menu/google/requirements.txt
```

## Architecture

### Data Flow

```
Website/API → Perl scraper (per store) → city CSV files (csv/) → merge.pl → combined CSV → upload_csv.pl → REST API → PostgreSQL
```

### Per-Store Directory Pattern

Each store directory follows a consistent structure:
- `grap.pl` (or store-specific name like `grap_711.pl`) — main scraper
- `get_city.pl` — lists available city codes for the target website
- `merge.pl` — merges per-city CSVs into a single output file (Shop_list.csv or similar)
- `make_shop_csv.pl` — optional post-processing to reshape data
- `csv/` — per-city output CSVs
- `grap.md` — store-specific scraping notes (target URLs, data structure, city codes)

### Shared Modules

- `lib/MyDB.pm` — PostgreSQL connection module (uses env vars: `POSTGRESQL_HOST`, `POSTGRESQL_DB`, `POSTGRESQL_USER`, `POSTGRESQL_PASS`)
- `grap_template/` — template for creating new store scrapers

### Upload System (`upload/`)

- `upload/app/upload_csv.pl` — main upload script; supports auth token via config file > CLI arg > `API_TOKEN` env var
- `upload/app/config.json` — API endpoint URL and auth token (copy from `config.json.example`)
- `upload/sync/` — Dancer2-based API server (port 5120) with PostgreSQL backend
- `upload/API/UploadAPI_integrated.pm` — integrated Dancer2 API module; large uploads (>500 lines or >50 branches) are processed asynchronously

### Menu/OCR Processing (`menu/`)

- Python-based pipeline using Google DocumentAI for menu image parsing
- `menu/google/parse_fixed.py`, `generate_standard_csv.py`

## CSV Data Format

Standard columns: `name,phone,city,region,detailed_address,latitude,longitude`

Some stores extend this with additional fields (Shop_info.csv, Shop_menu.csv). All files use UTF-8 encoding.

## Key Conventions

- All scraper scripts include delay mechanisms (`Time::HiRes::sleep`) to avoid being blocked
- HiLife (`hilife_v3.pl`) has the most sophisticated anti-bot handling (cookies, browser simulation, rotating delays)
- Chinese (Traditional) is used throughout: comments, docs, output messages, and filenames
- Each scraper is run independently from its own directory; there is no unified build/test system
