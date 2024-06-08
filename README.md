<p align="center">
<img height="180" src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/AppIcon.png" />
</p>

<h1 align="center">VirusTotal for macOS</h1>

<p align="center"> An elegant VirusTotal client built with Swift and SwiftUI</p>

<p align="center">
<a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README.md">English</a>,
<a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README_CN.md">简体中文</a>
</p>

## Quick Setup
You can get a free public API key from VirusTotal. Visit [VirusTotal's API page](https://www.virustotal.com/gui/my-apikey) to retrieve it.
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/API.png"/>

#### Downloads
<img src="https://img.shields.io/badge/macOS-14.0-green"/>

Please head to [Releases](https://github.com/Jerry23011/VirusTotal-macOS/releases) to get the latest dmg.
#### Bypassing macOS notarization
In case you got a popup saying "VirusTotal.app” will damage your computer. You should move it to the Bin", execute the following code in your Terminal.app. I don't have an Apple Developer membership. The app is open-source, feel free to compile it from source.

```
sudo xattr -rd com.apple.quarantine /Applications/VirusTotal.app
```

## Features
- Check API quota
- URL Analysis
- Remove tracking query in URL
- File Analysis
- System Service support for both URLs and files
- Drop URL on app icon to scan
- Drop file in app to scan
- Super light, the app is < 15MB
- Sandboxed app
- Auto-updates via Sparkle
## Privacy
This app is sandboxed and only contacts VirusTotal and GitHub (for downloading updates).
Note that this is NOT an official app from VirusTotal. All source code is available, so feel free to compile it yourself.
The data the app sends to VirusTotal conforms to VirusTotal's [Privacy Policy](https://docs.virustotal.com/docs/privacy-policy)
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
