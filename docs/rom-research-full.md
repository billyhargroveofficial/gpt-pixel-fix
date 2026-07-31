# Проверка прошивок и WebView для лага LaTeX в ChatGPT Android

Статус: прошивка физического Pixel не менялась. Позже, с явного разрешения
владельца, на Pixel был установлен локально подписанный экспериментальный
phase-4 APK с сохранением существующей сессии приложения. Это не тест
GrapheneOS на физическом устройстве.

Обновление после исходного отчёта: matched host-GPU и cross-install контроли
локализовали усилитель в современном WebView. При gate=false API 36 с
WebView 133 дал 4,36–9,88% jank и p50 18–19 мс. После установки на тот же API
36 точного официального WebView 145 результат стал 68,54–81,19% и p50
81–85 мс. API 37 с тем же WebView 145 дал 61,89–83,06% и p50 85–109 мс.
Обратная установка matching Trichrome/WebView 133 на API 37 вернула
0,00–8,21% и p50 16 мс.
На API 37 gate=true дал 0 WebViews, 0,63–1,26% steady-state jank и p50 16 мс.
Android 17 не является основной причиной: результат следует за поколением
WebView в обе стороны. Полный контроль находится в
`docs/android16-17-matched-control.md`.

## Уже установленная причина

В ChatGPT Android `1.2026.202` есть два пути отображения формул:

- быстрый нативный `ValdiLatexFormulaContent`;
- аварийный `WebViewLatexFormulaContent`, создающий отдельный Android WebView
  для каждого math-узла.

Statsig gate `3320767387` раскатан на 50% пользователей с бакетированием по
`userID`. У затронутого аккаунта gate вычисляется как `false`, поэтому выбор
медленного пути не зависит от Pixel, клавиатуры, прошивки, GPU или поставщика
WebView.

Даже при gate=`true` отдельные неподдерживаемые команды могут включить
process-global fallback до следующего force-stop. В реальном тяжёлом чате
найдено две команды `\xrightarrow`; после них приложение показывает 149
формульных WebView.

Это отдельная регрессия новых версий. В официально подписанной Google Play
версии `1.2026.160` gate и оба renderer уже присутствуют, но ошибка нативного
renderer хранится локально в composable одной формулы. Начиная как минимум с
`1.2026.195` и в текущей `1.2026.202` появился process-global `Throwable`
latch. Поэтому downgrade до `.160` ограничивает ущерб от неподдерживаемой
команды, но не помогает аккаунту с gate=`false`: у него и в `.160` все формулы
сразу идут через WebView.

Контроль на том же аккаунте и AVD:

| Содержимое | Gate | Формульные WebView | Janky frames | p50 |
|---|---:|---:|---:|---:|
| 120 отдельных поддерживаемых формул | true | 0 | 12,83% | 16 мс |
| те же 120 формул | false | 120 | 81,25% | 89 мс |
| реальный тяжёлый чат | true, но есть `\xrightarrow` | 149 | 87,06% | 150 мс |

Это объясняет, почему проблема не затрагивает всех Android-пользователей:
аккаунты находятся в разных rollout cohort, ответы содержат разные LaTeX
команды и разное число math-узлов.

## Почему это не проблема «всех Android»

В server-response cache Statsig из официального APK для gate `3320767387`
зафиксированы:

- bucketing key `userID`;
- rollout rule `50.00`;
- значение `false` для текущего авторизованного пользователя;
- значение `true` для анонимного пользователя на той же AVD.

Это важнее корреляции с маркой телефона. Проверки на Pixel 7/8/9 и AVD
повторяли один и тот же OpenAI-аккаунт, поэтому сохраняли один и тот же
`false` cohort. Друг на Honor использует другой аккаунт и может находиться в
другой половине rollout. Тот же тяжёлый чат на том же аккаунте тормозит и на
x86_64 Google AVD, а локальное переключение только этого gate на той же AVD
меняет результат с 81,25% jank и p50 89 мс на 12,83% и p50 16 мс.

Chrome не использует этот Android-native feature gate и renderer path.
Поэтому плавный web-клиент на том же Pixel согласуется с причиной в
официальном Android-приложении, а не опровергает её.

## Может ли Pixel дополнительно усиливать лаг

Корневая причина не Pixel-specific, но вторичный вклад Pixel/Android 17 пока
не следует объявлять полностью исключённым.

Perfetto показал одну и ту же цепочку на физическом Pixel и на x86_64 AVD с
host GPU, где нет Tensor, Mali и Pixel firmware:

- Pixel: `11 794` вызова `WebViewFunctor::drawVk`, в среднем `1,13 мс`;
  `draw-VRI[MainActivity]` в среднем `165 мс`, максимум `502 мс`;
- AVD: `8 947` вызовов `WebViewFunctor::drawGl`, в среднем `0,60 мс`;
  главный draw в среднем `255 мс`, максимум `460 мс`;
- в обоих случаях основные hotspots — `VizWebView`, `CrRendererMain`,
  `RenderThread` и main thread.

На Pixel GPU-time был `p50=2 мс`, `p99=5 мс` при общем frame-time
`p50=150 мс`. Поэтому Tensor/Mali не нужны для возникновения дефекта, а
гипотеза «Pixel GPU медленно рисует формулы» почти исключена. Основная цена
возникает на CPU-side обходе множества View/WebView и синхронизации потоков.

Cross-install устранил главный прежний конфаундер: Android 16 остаётся тем же,
но замена WebView 133 на WebView 145 переносит на него катастрофический лаг.
Обратная замена matching Trichrome/WebView 133 на API 37 убирает его.
Поэтому версия Android сама по себе не объясняет различие. У Honor остаются
другой аккаунтный cohort, WebView/provider build, Snapdragon 8 Gen 3 и OEM
scheduling MagicOS. Разрешение тоже влияет на абсолютный jank, но разница
площади экрана Pixel 9 Pro XL и Honor 400 Pro невелика и не объясняет переход
от «непригодно» к «плавно».

Минимальный решающий тест, когда Honor снова будет доступен:

1. войти на нём под тем же затронутым аккаунтом;
2. открыть на обоих телефонах один и тот же ответ со 120 простыми
   поддерживаемыми math-узлами без fallback-триггеров;
3. сделать force-stop, дождаться загрузки и собрать одинаковые 48 свайпов;
4. сравнить app/OS/WebView versions, size/density/refresh rate, число
   `WebViews` и `gfxinfo` p50/p95.

Если оба показывают 120 WebView, но Honor остаётся плавным, будет доказан
существенный вторичный OS/SoC-фактор. Если оба показывают 120 WebView и
тормозят, разницу почти полностью объясняет account cohort. Окончательный
вариант — матрица 2×2: оба аккаунта на обоих телефонах.

Связанные источники:

- стабильное процентное бакетирование Statsig:
  https://docs.statsig.com/feature-flags/conditions
- release notes Android 17 QPR1, включая отдельные исправления WebView:
  https://developer.android.com/about/versions/17/qpr1/release-notes
- характеристики экранов Pixel:
  https://support.google.com/pixelphone/answer/7158570
- характеристики Honor 400 Pro:
  https://www.honor.com/sg/phones/honor-400-pro/spec/

## Можно ли включить gate без переподписывания APK

В `1.2026.202` есть настоящий внутренний экран `Experiment overrides`, а
Statsig SDK умеет сохранить локальный override для gate `3320767387`. Однако
production UI показывает этот экран только при другом bootstrap gate
`2690524466=true`; у проверенного production-аккаунта он `false`. У экрана нет
отдельной manifest activity или найденного внешнего developer deep link.

Обычные способы доступа к данным приложения также закрыты:

- manifest содержит `android:allowBackup="false"`;
- APK не `debuggable`, поэтому `run-as` недоступен;
- Shizuku работает как shell UID и не читает private app data;
- отдельный `networkSecurityConfig` отсутствует, а современный Android по
  умолчанию не доверяет пользовательскому CA для такого приложения.

Блокировка Statsig-доменов после получения анонимного `true` также не является
обходом. Встроенный Statsig Android SDK `5.2.0` при `updateUser` сначала
вызывает `resetUser()` и загружает отдельный cache нового пользователя; если
его нет, gate до успешного network update возвращает `false`. Анонимное
значение не переносится в авторизованный `userID`.

При этом `Statsig.LOCAL_OVERRIDES` хранится глобально, а не в per-user cache,
но штатно записать туда нужный gate нельзя. Экран `Experiment overrides`
отрисовывается только когда `2690524466=true` либо приложение запущено во
внутреннем окружении OpenAI. Анонимный bootstrap содержит `3320767387=true`,
но не содержит `2690524466`, поэтому до входа экран тоже скрыт. Проверены
manifest components, typed Compose route, deep links, `ActivityResult` и
вызовы Statsig debug UI: доступного production-входа без root или
переподписывания APK не найдено. Более того, экран показывает только
server-provided список gates и не умеет добавить произвольный numeric gate.

С root можно изменить только приватный Statsig DataStore, оставив байты
официального APK и его сертификат нетронутыми. Нужный ключ:
`Statsig.LOCAL_OVERRIDES`, значение:
`{"gates":{"3320767387":true},"configs":{},"layers":{}}`. Для этого всё равно
нужен разблокированный загрузчик/root, что ослабляет security model и может
повлиять на Play Integrity и банковские приложения. GrapheneOS намеренно не
предоставляет root. Среди проверенных официально подписанных версий `.048`,
`.160`, `.167`, `.195` и `.202` не найдено версии, где native renderer
включён по умолчанию. Наименее плохой root-вариант — официальная `.160` плюс
локальный override: в ней сбой одной неподдерживаемой формулы ещё не включает
process-global fallback.

## Прямой A/B Google WebView и GrapheneOS Vanadium

На одном и том же rootable Android 17 AVD, аккаунте, тяжёлом чате и точной
последовательности из 48 свайпов менялся только системный WebView provider.
Проверялись официальный Google WebView и официальные APK Vanadium.

| Provider | Версия | Прогоны jank | p50 | Формульные WebView |
|---|---:|---:|---:|---:|
| Google WebView | 145 | 82,61%; 81,31% | 150 мс | 149 |
| Vanadium current | 151 | 78,24%; 79,17% | 150 мс | 149 |
| Vanadium из stable GrapheneOS `2026071500` | 150 | 88,24%; 81,19% | 150 мс | 149 |

Vanadium не устраняет архитектуру «один WebView на формулу». Небольшой разброс
процента jank между прогонами не меняет медиану кадра и не делает чат
пригодным к использованию.

Полные сырые результаты: `webview-ab-results.tsv`.

## Вывод по прошивкам

- GrapheneOS поддерживает Pixel 9 Pro XL (`komodo`) и использует Vanadium как
  системный WebView. Stable `2026071500` работает на Android 17 и содержит
  Vanadium `150.0.7871.124`; beta `2026072900` содержит
  `151.0.7922.47`. Обе эти точные версии уже проверены прямым provider A/B и
  не дали исправления.
- Cross-install официального Google WebView 145 на API 36 перенёс тяжёлую
  регрессию с собой, а matching WebView 133 на API 37 убрал её. Версия Android
  не является основной причиной. Актуальные Chromium providers, а не только
  версия прошивки, критичны для плохой ветки.
- В исходниках stable `2026071500` для сторонних приложений
  `setting_default_restrict_webview_dyn_code_loading=false`, то есть WebView
  JIT разрешён по умолчанию. Android Runtime JIT при этом выключен и заменён
  full AOT. Полная сборка с этим штатным состоянием всё равно дала
  91,79–100% jank в WebView condition.
- Последний GrapheneOS на Android 16, `2026061600`, содержал Vanadium 140.
  Он находится до обнаруженной WebView-145-era регрессии и потому
  теоретически интересен, но точная комбинация не тестировалась, ветка уже не
  текущая, downgrade защищён rollback index, а заморозка старого OS/WebView
  небезопасна.
- Текущий CalyxOS stable `7.2.2.0` использует Chromium/WebView
  `149.0.7827.48`. Точный provider не тестировался, но Android 16 +
  WebView 145 уже был катастрофически медленным, а проверенные 150/151 тоже
  остались медленными. Поэтому Android 16 у CalyxOS не является основанием
  ожидать исправление.
- Текущий LineageOS `23.2` официально собирается для `komodo` и использует
  AOSP Chromium WebView 150. Точная LineageOS-сборка не тестировалась; по
  поколению provider и неизменному account gate вероятность исправления
  низкая.
- Для GrapheneOS, CalyxOS, LineageOS, iodéOS, crDroid и /e/OS не найдено
  воспроизводимого отчёта, где прошивка исправила именно ChatGPT +
  LaTeX-heavy scroll.
- Смена ROM не меняет server-side cohort того же OpenAI `userID` и не может
  объединить 149 WebView, которые создаёт само приложение.
- Намеренно фиксировать WebView 133 на основном телефоне небезопасно: это
  security-critical компонент, а старая версия не получает последующие
  исправления уязвимостей.

Официальные источники:

- GrapheneOS build guide: https://grapheneos.org/build
- GrapheneOS releases: https://grapheneos.org/releases
- Vanadium: https://grapheneos.org/features#vanadium
- GrapheneOS WebView/Vanadium usage:
  https://grapheneos.org/usage#web-browsing
- Sandboxed Google Play: https://grapheneos.org/usage#sandboxed-google-play
- GrapheneOS installation: https://grapheneos.org/install/web
- GrapheneOS downgrade protection: https://grapheneos.org/usage#updates
- CalyxOS installation: https://calyxos.org/install/
- CalyxOS Chromium/WebView: https://calyxos.org/docs/development/build/chromium/
- CalyxOS `7.2.2.0` Chromium/WebView tag:
  https://gitlab.com/CalyxOS/lfs_prebuilts_calyx_chromium_arm64/-/tags/7.2.2.0
- LineageOS `komodo` metadata:
  https://github.com/LineageOS/lineage_wiki/blob/main/_data/devices/komodo.yml
- LineageOS current build targets:
  https://raw.githubusercontent.com/LineageOS/hudson/main/lineage-build-targets
- LineageOS Chromium WebView 150 update:
  https://github.com/LineageOS/android_external_chromium-webview_prebuilt_arm64/commit/aca8d63899707c568d48c412e2c34a8c11c4dd12

## Полная GrapheneOS-проверка

Полная тестовая сборка из stable source tag `2026071500` завершена. Был создан
отдельный `userdebug` emulator product на Android 17 с системным Vanadium
`150.0.7871.124.0`. Неизменённый официальный ARM64-only split APK ChatGPT
`1.2026.202` (`2620225`) запускался через test-only ARM64 native bridge.
Сеть эмулятора была `VALIDATED`; сервер вернул длинные ответы, после чего
измерялся именно клиентский scroll/render workload.

Один и тот же prompt запросил 120 отдельных простых display-формул. Сервер
выдал 118 формульных узлов в native condition и 114 в WebView condition.
Количество немного различается из-за недетерминированного ответа модели, но
выражение, структура отдельных блоков, APK, OS, provider, экран и 48 свайпов
оставались одинаковыми.

| Условие | Формульные узлы | WebView | Jank, три прогона | p50 |
|---|---:|---:|---:|---:|
| gate=true, native renderer | 118 | 0 | 2,12%; 2,91%; 0,00% | 17–18 мс |
| gate=false, WebView renderer | 114 | 114 | 91,79%; 96,41%; 100,00% | 73 мс |

Этот тест напрямую воспроизводит исходный дефект на GrapheneOS: смена только
renderer gate превратила плавный официальный клиент в почти полностью
тормозные кадры. Поэтому вывод больше не основан лишь на установке Vanadium в
Google AVD. Сама полная GrapheneOS runtime-среда также не исправляет плохой
cohort.

Сырые строки находятся в `experiments/graphene-native-build.tsv`.

Официальный ChatGPT APK выпускается только с ARM64 split. Поэтому x86_64
эмулятор GrapheneOS требует тестового ABI bridge. Такая сборка пригодна для
проверки UI-архитектуры, но не считается официальной production-сборкой
GrapheneOS и не доказывает её security properties.

## Риск физической установки

Установка GrapheneOS на Pixel и возврат на stock требуют разблокировки,
прошивки и повторной блокировки bootloader; пользовательские данные стираются.
На текущих данных ожидаемая вероятность исправления низкая: тот же Vanadium
уже проверен напрямую и оставил 149 WebView. Физическая прошивка не должна
выполняться без отдельного явного разрешения и резервной копии.

Root/Magisk позволяет изменить приватный Statsig override у официально
подписанного APK и действительно включает быстрый native renderer, но требует
unlocked bootloader и ослабляет verified boot. Это может нарушить Play
Integrity, Wallet, банковские приложения, DRM и обычный OTA-процесс.
GrapheneOS root не поддерживает. Такой эксперимент разумен только на отдельном
тестовом устройстве и не рекомендуется для основного Pixel.
