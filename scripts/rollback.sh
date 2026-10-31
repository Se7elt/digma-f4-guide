#!/usr/bin/env sh
# Возвращает всё, что отключил optimize.sh, и включает анимации.
# Использование: ./scripts/rollback.sh

set -eu

ADB="${ADB:-adb}"

PACKAGES="
com.yandex.browser
ru.yandex.translate
ru.vk.store
ru.litres.android
ru.libapp
com.android.printspooler
com.android.printservice.recommendation
com.android.bips
com.android.dreams.basic
com.android.dreams.phototable
com.android.music
com.android.musicfx
com.android.providers.calendar
com.android.smspush
com.DeviceTest
com.wetao.deviceguide
android.rockchip.update.service
com.google.android.tts
com.svox.pico
"

echo "== Проверка связи =="
"$ADB" get-state >/dev/null 2>&1 || {
  echo "Устройство не найдено. Проверьте кабель и отладку по USB." >&2
  exit 1
}

INSTALLED="$("$ADB" shell pm list packages | tr -d '\r')"

echo
echo "== Включаем обратно =="
for pkg in $PACKAGES; do
  if ! printf '%s\n' "$INSTALLED" | grep -qx "package:$pkg"; then
    echo "пропуск (нет на устройстве): $pkg"
    continue
  fi
  printf '%s -> ' "$pkg"
  "$ADB" shell pm enable "$pkg" | tr -d '\r'
done

echo
echo "== Анимации =="
"$ADB" shell settings put global window_animation_scale 1
"$ADB" shell settings put global transition_animation_scale 1
"$ADB" shell settings put global animator_duration_scale 1
echo "включены"

echo
echo "Если приложение было удалено (pm uninstall --user 0), верните его так:"
echo "  adb shell cmd package install-existing <пакет>"
echo "Приложения из /data/app (например, RuStore) придётся скачать заново."
