<p align="center">
<img height="180" src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/AppIcon.png" />
</p>

<h1 align="center">VirusTotal for macOS</h1>

<p align="center"> An elegant VirusTotal client built with Swift and SwiftUI</p>

<p align="center">
<a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README.md">English</a> · <a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README_CN.md">简体中文</a>
</p>

## Quick Setup
You can get a free public API key from VirusTotal. Visit [VirusTotal's API page](https://www.virustotal.com/gui/my-apikey) to retrieve it.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/API.png"/>
#### Downloads
<img src="https://img.shields.io/badge/macOS-14.0-green"/>

Please head to [Releases](https://github.com/Jerry23011/VirusTotal-macOS/releases) to get the latest dmg.
#### Bypassing macOS notarization
In case you get a popup saying "VirusTotal.app” will damage your computer. You should move it to the Bin", execute the following code in your Terminal.app. This is because I don't have an Apple Developer membership. Since the app is open-source, feel free to compile it from source if you have any concerns.

```
sudo xattr -rd com.apple.quarantine /Applications/VirusTotal.app
```
#### Homebrew
```
brew install marsanne/cask/virustotal
```
## Features
- Upload files and URLs to VirusTotal
- View Analysis Report on VirusTotal
- View Analysis Reports in app
- Check API quota
- Remove tracking query in URL
- System Service support for both URLs and files
- Drop an URL on the app icon to scan
- Drop a file in app to scan
- View Scan History
- Mini mode that swiftly opens VT website after uploads
- Super light, the app is < 15MB
- Sandboxed app
- Auto-updates via Sparkle
## Privacy
This app is sandboxed and only contacts VirusTotal and GitHub (for downloading updates).
Note that this is NOT an official product of VirusTotal. However, all source code is available, so feel free to compile it yourself.

Logs are stored locally and never sent anywhere else.

The data the app sends to VirusTotal conforms to VirusTotal's [Privacy Policy](https://docs.virustotal.com/docs/privacy-policy)
## Contributing
Issues and PRs are welcomed! If you'd like to contribute to localization, please refer to [this guide](https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/Docs/Localization-Guide_EN.md)
## Acknowledgements
See [Acknowledgements](https://github.com/Jerry23011/VirusTotal-macOS/blob/main/ACKNOWLEDGEMENTS.md)
## Screenshots
### Check Quota
Retrieve your hourly, daily, and monthly quota.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/HomePage_EN.png"/>
### File Scanning
Upload a File and get an analysis report
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/File_EN.gif"/>
### URL Scanning
Scan a URL with ease
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/URL_EN.png"/>
### Scan History
View scan history
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/ScanHistory_EN.png"/>