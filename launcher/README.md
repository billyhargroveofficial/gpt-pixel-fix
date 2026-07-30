# ChatGPT Chrome launcher

Small Android launcher that opens `https://chatgpt.com/` in a Chrome Custom
Tab. The page is rendered by Chrome and shares Chrome's existing cookies.

The launcher contains no WebView, does not inject JavaScript, and does not read
or store the browser session.

Chrome keeps a small trusted-browser toolbar because `chatgpt.com` has not
authorized this APK through Digital Asset Links. The URL bar is configured to
hide while scrolling.

Build:

```sh
chmod +x build.sh
./build.sh
```

Install:

```sh
adb install -r build/chatgpt-chrome.apk
```
