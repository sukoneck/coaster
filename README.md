# Summary

Price tracker for macOS navbar. What a ride 🎢

# Install

Versioned releases available [here](https://github.com/sukoneck/coaster/releases). Latest version available on Brew:
```sh
brew tap sukoneck/coaster https://github.com/sukoneck/coaster
brew install --cask coaster
```

This app is not signed/notarized, so macOS may block it. If macOS says it's damaged, run:
```sh
xattr -dr com.apple.quarantine /Applications/coaster.app
```

To launch at login:
```
System Settings → General → Login Items → add Coaster
```
