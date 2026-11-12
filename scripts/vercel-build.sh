#!/bin/bash
set -e

# 1. Unduh file wajib SQLite untuk web
mkdir -p web
curl -sL -o web/sqlite3.wasm https://raw.githubusercontent.com/tekartik/sqflite/master/sqflite_common_ffi_web/web/sqlite3.wasm
curl -sL -o web/sqflite_sw.js https://raw.githubusercontent.com/tekartik/sqflite/master/sqflite_common_ffi_web/web/sqflite_sw.js

# 2. Jalankan build Flutter
flutter/bin/flutter create . --platforms=web
flutter/bin/flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY