#!/bin/bash
set -e

# 1. Unduh file wajib SQLite untuk web (WASM)
mkdir -p web
echo "Downloading sqlite3.wasm..."
curl -fsSL -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/latest/download/sqlite3.wasm

# 2. Jalankan build Flutter
flutter/bin/flutter create . --platforms=web
flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY