<p align="center">
<img height="180" src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/AppIcon.png" />
</p>

<h1 align="center">VirusTotal для macOS</h1>

<p align="center">Элегантный клиент VirusTotal, написанный на Swift и SwiftUI</p>

<p align="center">
<a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README.md">English</a> · <a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README_CN.md">简体中文</a> · <a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README_RU.md">Русский</a>
</p>

## Быстрая настройка
Бесплатный публичный API-ключ можно получить на странице [VirusTotal API](https://www.virustotal.com/gui/my-apikey).
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/API.png"/>

#### Загрузки
<img src="https://img.shields.io/badge/macOS-14.0+-green"/>

Последнюю версию dmg-файла можно скачать на странице [Releases](https://github.com/Jerry23011/VirusTotal-macOS/releases).

#### Обход нотаризации macOS
Если macOS выдаёт предупреждение «"VirusTotal.app" повредит ваш компьютер. Его следует переместить в корзину», выполните следующую команду в Terminal.app. Это связано с отсутствием членства Apple Developer. Приложение имеет открытый исходный код — при наличии сомнений можно скомпилировать его самостоятельно.

```
sudo xattr -rd com.apple.quarantine /Applications/VirusTotal.app
```

Также это можно сделать через «Системные настройки». Инструкция доступна на [странице поддержки Apple](https://support.apple.com/102445#openanyway).

#### Homebrew
```
brew install marsanne/cask/virustotal
```

## Возможности
- Анализ файлов
- Анализ URL
- Проверка использования API
- Удаление параметров отслеживания из URL
- Поддержка системных сервисов macOS
- История сканирований
- Мини-режим
- Монитор загрузок
- Изолированное приложение (Sandbox)
- Автообновление через Sparkle

## Конфиденциальность
Приложение работает в песочнице и обращается по сети только к VirusTotal и GitHub (для загрузки обновлений).

Обратите внимание: это **неофициальный** продукт VirusTotal. Весь исходный код открыт — при наличии сомнений можно изучить его и скомпилировать самостоятельно.

Журналы хранятся локально и никуда не передаются.

Данные, отправляемые в VirusTotal, соответствуют [Политике конфиденциальности](https://docs.virustotal.com/docs/privacy-policy) VirusTotal.

## Участие в разработке
Приветствуются Issues и Pull Request! Если вы хотите помочь с локализацией, ознакомьтесь с [руководством](https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/Docs/Localization-Guide_EN.md).

## Благодарности
См. [Acknowledgements](https://github.com/Jerry23011/VirusTotal-macOS/blob/main/ACKNOWLEDGEMENTS.md).

## Скриншоты
### Проверка квоты API
Просматривайте почасовую, суточную и месячную квоту.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/HomePage_EN.png"/>

### Анализ файлов
Загрузите файл и получите отчёт об анализе.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/File_EN.gif"/>

### Анализ URL
Легко проверьте любой URL.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/URL_EN.png"/>

### Пакетная проверка файлов
Загружайте несколько файлов одновременно.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/FileBatch_EN.png"/>

### История сканирований
Просматривайте историю проверок.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/ScanHistory_EN.png"/>
