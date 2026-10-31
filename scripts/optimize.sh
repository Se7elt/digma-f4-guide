#!/usr/bin/env sh
# Отключает предустановленный мусор и выключает анимации.
#
#   ./scripts/optimize.sh          — примерный прогон, ничего не меняет
#   ./scripts/optimize.sh --yes    — применить
#
# Всё обратимо: ./scripts/rollback.sh

set -eu

ADB="${ADB:-adb}"
APPLY=0

[ "${1:-}" = "--yes" ] && APPLY=1

# Список проверен на Digma F4 / WT576V1RU20250909.
# На другой прошивке часть пакетов может отсутствовать — они будут пропущены.
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
echo "== Приложения =="
for pkg in $PACKAGES; do
  if ! printf '%s\n' "$INSTALLED" | grep -qx "package:$pkg"; then
    echo "пропуск (нет на устройстве): $pkg"
    continue
  fi

  if [ "$APPLY" -eq 0 ]; then
    echo "будет отключён: $pkg"
  else
    printf '%s -> ' "$pkg"
    "$ADB" shell pm disable-user --user 0 "$pkg" | tr -d '\r'
  fi
done

echo
echo "== Анимации =="
if [ "$APPLY" -eq 0 ]; then
  echo "будут выставлены в 0:"
  echo "  window_animation_scale"
  echo "  transition_animation_scale"
  echo "  animator_duration_scale"
else
  "$ADB" shell settings put global window_animation_scale 0
  "$ADB" shell settings put global transition_animation_scale 0
  "$ADB" shell settings put global animator_duration_scale 0
  echo "выключены"
fi

echo
if [ "$APPLY" -eq 0 ]; then
  echo "Это был примерный прогон. Для применения: $0 --yes"
else
  echo "Готово. Проверьте: adb shell pm list packages -d"
  echo "Откат: ./scripts/rollback.sh"
fi
