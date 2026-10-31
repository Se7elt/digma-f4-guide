#!/usr/bin/env sh
# Снимает исходное состояние устройства в папку f4-backup/.
# Использование: ./scripts/audit.sh [папка]

set -eu

ADB="${ADB:-adb}"
OUT="${1:-f4-backup}"

"$ADB" get-state >/dev/null 2>&1 || {
  echo "Устройство не найдено. Проверьте кабель и отладку по USB." >&2
  exit 1
}

mkdir -p "$OUT"

echo "== Устройство =="
"$ADB" shell getprop ro.product.model          | tr -d '\r' | tee "$OUT/model.txt"
"$ADB" shell getprop ro.build.display.id       | tr -d '\r' | tee "$OUT/firmware.txt"
"$ADB" shell getprop ro.build.version.release  | tr -d '\r' | tee "$OUT/android.txt"
"$ADB" shell getprop ro.product.cpu.abi        | tr -d '\r' | tee "$OUT/abi.txt"

echo
echo "== Пакеты =="
"$ADB" shell pm list packages      | tr -d '\r' > "$OUT/packages-all.txt"
"$ADB" shell pm list packages -s   | tr -d '\r' > "$OUT/packages-system.txt"
"$ADB" shell pm list packages -3   | tr -d '\r' > "$OUT/packages-user.txt"
"$ADB" shell pm list packages -d   | tr -d '\r' > "$OUT/packages-disabled-before.txt"
echo "всего:      $(wc -l < "$OUT/packages-all.txt")"
echo "системных:  $(wc -l < "$OUT/packages-system.txt")"
echo "сторонних:  $(wc -l < "$OUT/packages-user.txt")"
echo "отключено:  $(wc -l < "$OUT/packages-disabled-before.txt")"

echo
echo "== Память и диск =="
"$ADB" shell df -h /data          | tr -d '\r' | tee "$OUT/storage-before.txt"
"$ADB" shell head -3 /proc/meminfo | tr -d '\r' | tee "$OUT/meminfo-before.txt"

echo
echo "== Кто занимает память =="
"$ADB" shell 'dumpsys meminfo | sed -n "/Total PSS by process/,/Total PSS by OOM/p" | head -15' \
  | tr -d '\r' | tee "$OUT/meminfo-processes.txt"

echo
echo "Готово. Файлы в: $OUT"
