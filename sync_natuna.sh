#!/bin/bash
echo "Menarik data dari GitHub dan membuat NatunaPOS.md..."
repo-to-md ajat888/NatunaPOS | python3 -c "
import sys
sys.stdin.reconfigure(encoding='utf-8', errors='replace')
sys.stdout.reconfigure(encoding='utf-8')
state = 0
for line in sys.stdin:
    line = line.replace('в”њв”Ђв”Ђ', '├── ').replace('в””в”Ђв”Ђ', '└── ').replace('в”‚', '│').replace('В§', '§').replace('рџ”ґ', '🔴').replace('рџ”„', '🔄').replace('рџ§­', '🧭').replace('в†’', '→').replace('вЂ”', '—')
    if line.startswith('file: '):
        print(line, end='')
        if line.endswith('.dart\n') or line.endswith('.py\n'):
            print('\`\`\`\n[Isi kode sengaja dihilangkan untuk menghemat token AI]\n\`\`\`')
            state = 1
        else:
            state = 0
        continue
    if state == 1:
        if line.startswith('\`\`\`'): state = 2
        continue
    if state == 2:
        if line.startswith('\`\`\`'): state = 0
        continue
    print(line, end='')
" > /sdcard/Documents/NatunaPOS.md
echo "✅ Selesai! File NatunaPOS.md terbaru sudah siap di folder Documents."
