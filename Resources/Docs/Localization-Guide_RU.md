# Начало работы с локализацией
VirusTotal использует Xcode String Catalog для управления переводами. Ниже описаны шаги, необходимые для начала локализации приложения.

### Установка Xcode 15+
Xcode можно установить из [Mac App Store](https://apps.apple.com/app/xcode/id497799835) или скачать бета-версию на странице [Apple Developer](https://developer.apple.com/xcode/resources/).

### Клонирование и сборка проекта
1. [Сделайте форк проекта](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo) на GitHub.
2. Склонируйте проект на Mac с помощью [git](https://docs.github.com/en/get-started/getting-started-with-git) или [GitHub Desktop](https://desktop.github.com).
3. Откройте проект и выполните сборку.

### Добавление языка в String Catalog
Теперь можно приступить к добавлению собственного языка!

1. Всего нужно перевести 4 файла.
2. Откройте `VirusTotal → Localizable.xcstrings`, `VirusTotal → InfoPlist.xcstrings`, `VirusTotal → ServicesMenu.xcstrings` и `VirusTotal → AppShortcuts.xcstrings`. Именно эти файлы `.xcstrings` требуют перевода. `AppShortcuts.xcstrings` содержит фразы для Siri — укажите естественные варианты команд на вашем языке.
3. Нажмите на файл `Localizable.xcstrings`, затем кнопку `+`, чтобы увидеть список доступных языков. Если нужного языка нет в списке (например, канадский английский), прокрутите вниз и выберите `More Languages`.
4. После добавления языка можно начинать перевод 😉

### Предварительный просмотр переводов
После завершения перевода полезно запустить приложение и проверить результат. Переключить язык интерфейса на переведённый можно за несколько кликов.

1. Найдите значок VirusTotal на верхней панели Xcode и нажмите на него.
2. Нажмите `Edit Scheme...`.
3. На левой боковой панели выберите вкладку `RUN`, затем перейдите в `Options`.
4. Прокрутите вниз до поля `App Language` и выберите переведённый язык.
5. Закройте вкладку и запустите приложение через ⌘R, чтобы увидеть переводы.

### Публикация изменений на GitHub
После проверки локализации необходимо отправить изменения на GitHub и создать Pull Request.

- [Создать Pull Request](https://docs.github.com/en/pull-requests).

После этого остаётся дождаться проверки мейнтейнером — и ваши переводы войдут в следующий релиз.

### Дополнительные ресурсы
- [Localization — Apple Developer](https://developer.apple.com/documentation/Xcode/localization)
- [Localizing and varying text with a string catalog — Apple Developer](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Discover String Catalogs — WWDC23 Videos](https://developer.apple.com/videos/play/wwdc2023/10155)
- [Apple Localization Glossaries](https://applelocalization.com)
