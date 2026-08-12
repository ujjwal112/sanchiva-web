# Sanchiva Mobile (Flutter)

Cross-platform mobile app for **Sanchiva**, using the same backend APIs as the web app.

> **New AI / Grok session for mobile only:** open and follow  
> [`MOBILE_SESSION.md`](./MOBILE_SESSION.md)  
> Paste the prompt at the bottom of that file into a fresh chat.

## Design

UI inspired by the reference finance screenshots (purple hero, orange CTAs, soft cards, bottom nav).

Reference copies: `design_ref/` (from your Screenshots folder).

## Prerequisites

- Flutter stable (installed at `C:\Users\ujjwa\flutter`)
- Android Studio + SDK
- VS Code with **Dart** + **Flutter** extensions
- Running Sanchiva API (`npm run dev` in monorepo root)

## Configure API

Live backend (Oracle + HTTPS): **`https://sanchivaorg.duckdns.org`**

| Where you run the app | API base URL |
|----------------------|--------------|
| Android phone / emulator | `https://sanchivaorg.duckdns.org` (auto) |
| iOS | `https://sanchivaorg.duckdns.org` (auto) |
| Chrome / Edge / Windows desktop | `http://localhost:5000` (auto — local API) |
| Force production on desktop | `--dart-define=API_BASE=https://sanchivaorg.duckdns.org` |
| Force local API on phone | `--dart-define=API_BASE=http://192.168.x.x:5000` |

```bash
# Phone / emulator → production API (default for Android)
flutter run

# Desktop/web against production
flutter run -d chrome --dart-define=API_BASE=https://sanchivaorg.duckdns.org
flutter run -d windows --dart-define=API_BASE=https://sanchivaorg.duckdns.org

# Desktop against local API (default for chrome/windows)
flutter run -d chrome
```

Web app (Vite) stays at: **http://localhost:5173/**

## Run

```bash
cd sanchiva_mobile
flutter pub get
flutter devices
flutter run
```

In VS Code: open `sanchiva_mobile`, press **F5** (Flutter).

## Features (v1)

- Onboarding (START)
- Email/password login, guest login, signup
- Dashboard (balance, KPIs, spend trend) via `/api/dashboard`
- Expenses list + add via `/api/expenses`
- Monetary overview (income/assets/lent + gold spot) via `/api/monetary/*`, `/api/metals/latest`
- Loans list via `/api/loans`
- Events list via `/api/events`

## iOS

Build/run iOS on a **Mac** with Xcode. Same codebase.
