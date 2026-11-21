# Animal Ball Blaster — Adventure Edition (Godot 4)

## Что добавлено
- Главное меню с краткой статистикой.
- Сохранение монет, очков, звёзд, открытого этапа и купленных цветов шариков.
- Четыре биома: луг (1–3), пустыня (4–6), снежные горы (7–9), волшебный остров (10).
- Финальный босс на 10-м уровне, которого нужно поразить три раза.
- Магазин двух дополнительных цветов шариков за монетки.
- Переход на следующий уровень только после спасения всех зверят.
- Частицы, подпрыгивание зверят, звуковые эффекты, бонусные выстрелы и награды.

## Запуск
1. Установите Godot Engine 4.3 или новее.
2. Откройте `project.godot`.
3. Нажмите F6/F5.

## Сборка APK
1. Установите Android Studio / Android SDK и JDK 17.
2. В Godot: Editor → Manage Export Templates → установите шаблоны.
3. Project → Export → Add… → Android.
4. Укажите Android SDK в Editor Settings → Export → Android.
5. Настройте debug keystore.
6. Нажмите Export Project и сохраните `AnimalBallBlaster.apk`.

Архив содержит исходный проект Godot, не готовый APK. Для APK необходима сборка через Godot с Android SDK.

## Автоматическая сборка APK через GitHub
Смотрите инструкцию `НАЧНИ_ЗДЕСЬ_GITHUB.md`. В архив добавлены Android export preset и GitHub Actions workflow.
