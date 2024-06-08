# Getting Started on Localization
VirusTotal uses Xcode String Catalog to manage translations, so the following steps are what you need to get started on localizing the app.
### Installing Xcode 15+
You can install Xcode from the [Mac App Store](https://apps.apple.com/app/xcode/id497799835) or its beta versions on [Apple Developer](https://developer.apple.com/xcode/resources/).
### Cloning and building the project
1. [Fork the project](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo) on GitHub
2. Use git to clone the project from GitHub to your Mac. You can do this by using the [git command line tool](https://docs.github.com/en/get-started/getting-started-with-git) or  [GitHub Desktop](https://desktop.github.com).
4. Open the project and build it
### Adding your language to String Catalog
Now you can start to add your own language!
1. There are 3 files in total you need to translation.
2. Navigate to `VirusTotal -> Localizable.xcstrings`,  `VirusTotal -> InfoPlist.xcstrings`, and `VirusTotal -> ServicesMenu.xcstrings`. These three `.xcstrings` files are what you are going to work on.
3. Click on the `Localizable.xcstrings` file and click the `+` button to find a list of available options. If you don't see the language you want to localize on the list (e.g. Canadian English). Scroll all the way down to the bottom of the menu to find `More Languages`.
4. After you add a language, you can start translating 😉
### Previewing your translations
After you are done with your translations, it's nice to run the app and go over your work. You can set the app language to the one that you did with a simple few clicks.
1. Find VirusTotal's icon on the top toolbar of Xcode and click on it
2. Click on `Edit Scheme...`
3. Select the `RUN` tab on the left sidebar and go to `Options`
4. Scroll down to find `App Language`, then choose the one you localized for
5. Close the tab and use ⌘R to run the app and see your translations
### Pushing your changes to GitHub
After you finish checking your localization, it's time to push the changes to GitHub and start a pull request.
- [Start a Pull Request](https://docs.github.com/en/pull-requests).
Now you can wait for a maintainer's review and get your translations adopted in the next release version.
### Additional Resources
- [Localization - Apple Developer](https://developer.apple.com/documentation/Xcode/localization)
- [Localizing and varying text with a string catalog - Apple Developer](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Discover String Catalogs - WWDC23 Videos](https://developer.apple.com/videos/play/wwdc2023/10155)
- [Apple Localization Glossaries](https://applelocalization.com)