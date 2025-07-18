<p align="center">
<img height="180" src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/AppIcon.png" />
</p>

<h1 align="center">VirusTotal for macOS</h1>

<p align="center"> 优雅的 VirusTotal 客户端，使用 Swift 和 SwiftUI 构建</p>

<p align="center">
<a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README.md">English</a> · <a href="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/README_CN.md">简体中文</a>
</p>

## 快速设置
你可以在 [VirusTotal API 页面](https://www.virustotal.com/gui/my-apikey)获取一个免费的公共 API 密钥。
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/API.png"/>
#### 下载
<img src="https://img.shields.io/badge/macOS-14.0+-green"/>

请前往 [Releases](https://github.com/Jerry23011/VirusTotal-macOS/releases) 以获取最新的 dmg 文件。
#### 绕过 macOS 公证
如果 macOS 提示"无法打开 “VirusTotal.dmg”，因为它来自身份不明的开发者。macOS 无法验证此 App 是否包含恶意软件。“ 这是因为我没有 Apple Developer 的会员，可以在终端中输入如下命令绕过。App 本身是开源的，如果不放心可以自行编译

```
sudo xattr -rd com.apple.quarantine /Applications/VirusTotal.app
```

或者你可以在 系统设置.app 中操作这步，你可以在这个[Apple 支持页面](https://support.apple.com/102445#openanyway)上找到对应步骤
#### Homebrew
```
brew install marsanne/cask/virustotal
```
## 功能
- 文件分析
- 网址分析
- 检查 API 用量
- 移除 URL 中的追踪链接
- 集成 macOS 系统服务
- 扫描历史记录
- 迷你模式
- 沙盒 App
- Sparkle 自动更新
## 隐私
采用 App 沙盒，只通过网络连接 VirusTotal 和 GitHub（下载更新）
请注意：本 App 不是 VirusTotal 的官方程序。但所有源代码都是公开的，不放心请检查代码并自行编译

日志文件仅存储在本地且不会发送到任何外部存储

所有发送到 VirusTotal 的数据均遵循 VirusTotal [隐私政策](https://docs.virustotal.com/docs/privacy-policy)
## 贡献
我们欢迎 Issue 和 PR！如果你有兴趣做本地化，请参考[这篇文档](https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/Docs/Localization-Guide_EN.md)
## 致谢
请见 [Acknowledgements](https://github.com/Jerry23011/VirusTotal-macOS/blob/main/ACKNOWLEDGEMENTS.md)
## 截图
### 检查 API 用量
获取每小时、每日和每月的配额。
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/HomePage_CN.png"/>
### 文件分析
上传文件并获取分析报告

<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/File_CN.gif"/>

### URL 分析
轻松扫描 URL
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/URL_CN.png"/>
### 扫描历史
查看扫描历史
<img src="https://github.com/Jerry23011/VirusTotal-macOS/blob/main/Resources/ScanHistory_CN.png"/>
