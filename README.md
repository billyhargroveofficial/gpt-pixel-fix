# gpt-pixel-fix

Reverse-engineering notes, reproducible patch scripts, measurements, and
screenshots for severe LaTeX scrolling jank in ChatGPT Android `1.2026.202`.

## Коротко

Проблема оказалась не клавиатурой и не специфическим дефектом Tensor/Mali.
Официальное приложение содержит два пути рендера формул:

- быстрый нативный `ValdiLatexFormulaContent`;
- запасной `WebViewLatexFormulaContent`, создающий отдельный Android WebView
  почти для каждой формулы.

Statsig gate `3320767387` раскатан на 50% пользователей с бакетированием по
`userID`. Для исследованного аккаунта gate возвращал `false`. Кроме того,
ошибка нативного рендера одной неподдержанной формулы, например
`\xrightarrow`, записывалась в process-global latch и отправляла в WebView
все последующие формулы.

| Контролируемый тест | WebViews | Janky frames | p50 |
|---|---:|---:|---:|
| 120 формул, gate=false | 120 | 81.25% | 89 ms |
| Те же 120 формул, gate=true | 0 | 12.83% | 16 ms |
| Реальный тяжёлый чат после `\xrightarrow` | 149 | 87.06% | 150 ms |

Поздний matched control уточнил, почему последняя прошивка Pixel страдала
особенно сильно:

| Платформа | Gate | WebViews | Jank, три прогона | p50 |
|---|---:|---:|---:|---:|
| Android 16 / WebView 133 | false | 120 | 9.88%, 4.36%, 4.75% | 18–19 ms |
| Android 17 / WebView 145 | false | 120 | 61.89%, 80.47%, 83.06% | 85–109 ms |
| Android 17 / WebView 145 | true | 0 | 14.02% settling, 0.63%, 1.26% | 16 ms |

То есть исследованный аккаунт попал в медленный renderer cohort, а
Android-17/WebView-145 stack дополнительно катастрофически усилил цену этого
пути. Контроль пока не разделяет вклад самого Android 17 и WebView 145.

Экспериментальный phase-4 patch:

1. принудительно включает уже встроенный нативный renderer;
2. не даёт одной ошибке переключить весь процесс на WebView;
3. заставляет приложение использовать локальный исправленный MathJax bundle;
4. добавляет нужные команды/шрифты и распознавание display math внутри
   Markdown quotes.

На физическом Pixel 9 Pro XL исследованный чат после патча показывал
`0 WebViews`, формулы отображались, а скролл стал визуально плавным.

## Важный статус

Это исследовательский proof of concept, а не полноценная замена официального
приложения:

- холодная загрузка очень длинного чата всё ещё иногда оставляет отдельные
  формулы пустыми из-за lifecycle/cache/decode цепочки
  `LatexView -> Asset -> Image`;
- inline-компоненты не умеют нормально переноситься и могут начать формулу с
  новой строки или обрезать слишком широкое SVG;
- остаются отдельные неподдержанные или повреждённые формулы;
- переподписанный APK теряет подпись Google Play. Чистый вход, Google OAuth,
  Play Integrity и обновления из Play Store могут не работать.

Поэтому долгосрочное исправление должен выпустить OpenAI в официально
подписанном приложении. Встроенный bug report был отправлен из аккаунта
`2026-07-31`; точный текст находится в
[`docs/openai-bug-report.md`](docs/openai-bug-report.md).

## Состав репозитория

- `patches/phase1/` — два минимальных DEX patch: gate и global fallback latch;
- `patches/phase4/` — MathJax/Valdi bundle, Markdown regex patches и сборка
  итогового split-APK set;
- `diagnostics/phase5/` — диагностическая инструментация renderer lifecycle,
  не release build;
- `experiments/` — A/B scripts и сырые таблицы;
- `evidence/` — hashes, verification output и обезличенные screenshots;
- `launcher/` — независимый Chrome Custom Tab launcher как безопасный
  официальный-web workaround;
- `docs/` — причина, дизайн патча, валидация, ограничения и исследование ROM.

## Воспроизводимая сборка

Репозиторий намеренно не содержит APK OpenAI, пользовательские базы, cookies,
сессии или signing keys.

Положите точный официальный split set `1.2026.202` в
`patches/phase1/original/`, затем:

```sh
cd patches/phase1
CHATGPT_PHASE4_INPUT_DIR=../phase4/input ./build.sh

cd ../phase4
./build.sh
```

Скрипты проверяют SHA-256 входов и ожидаемые байты перед применением каждого
offset patch. Подробности и риски:

- [`docs/patch-design.md`](docs/patch-design.md)
- [`docs/validation.md`](docs/validation.md)
- [`docs/installation-and-signing.md`](docs/installation-and-signing.md)
- [`docs/known-limitations.md`](docs/known-limitations.md)

## GrapheneOS

GrapheneOS/Vanadium не меняют аккаунтный rollout OpenAI и архитектуру
«WebView на формулу». Прямая замена Google WebView на Vanadium в
контролируемом A/B сохранила `149 WebViews` и `p50=150 ms`. Прошивка может
существенно менять тяжесть уже существующего дефекта: matched control нашёл
большую регрессию в комбинированном Android-17/WebView-145 image относительно
Android-16/WebView-133. Но прошивка не гарантирует хороший аккаунтный cohort,
а вклад OS и WebView ещё не разделён cross-install тестом. Полный журнал
исследования находится в
[`docs/rom-research-full.md`](docs/rom-research-full.md).

## Disclaimer

Not affiliated with or endorsed by OpenAI, Google, or GrapheneOS. Use only on
devices and APK copies you are authorized to analyze. Do not install the
patched package over valuable app data without a tested backup and recovery
plan.
