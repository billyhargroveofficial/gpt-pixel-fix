package dev.billy.chatgptchrome;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;

/**
 * Opens ChatGPT in a Chrome Custom Tab.
 *
 * The page is rendered by Chrome and shares Chrome's cookies. This APK neither
 * embeds a WebView nor reads, stores, or transfers the browser session.
 */
public final class MainActivity extends Activity {
    private static final Uri CHATGPT = Uri.parse("https://chatgpt.com/");
    private static final String CHROME_PACKAGE = "com.android.chrome";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        openChatGpt();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        openChatGpt();
    }

    private void openChatGpt() {
        Intent tab = new Intent(Intent.ACTION_VIEW, CHATGPT);

        // A null Custom Tabs session binder is the protocol marker that makes
        // Chrome open a Custom Tab instead of a normal browser tab.
        Bundle customTabExtras = new Bundle();
        customTabExtras.putBinder(
                "android.support.customtabs.extra.SESSION",
                null);
        tab.putExtras(customTabExtras);

        tab.putExtra(
                "android.support.customtabs.extra.ENABLE_URLBAR_HIDING",
                true);
        tab.putExtra(
                "android.support.customtabs.extra.TITLE_VISIBILITY",
                0);
        tab.putExtra(
                "android.support.customtabs.extra.EXTRA_ENABLE_INSTANT_APPS",
                false);
        tab.putExtra(
                "androidx.browser.customtabs.extra.SHARE_STATE",
                2);
        tab.putExtra(
                "androidx.browser.customtabs.extra.COLOR_SCHEME",
                2);
        tab.putExtra(
                "android.support.customtabs.extra.TOOLBAR_COLOR",
                Color.rgb(13, 13, 13));
        tab.putExtra(
                "androidx.browser.customtabs.extra.NAVIGATION_BAR_COLOR",
                Color.BLACK);
        tab.putExtra(
                Intent.EXTRA_REFERRER,
                Uri.parse("android-app://" + getPackageName()));

        // Prefer real Chrome so the renderer and logged-in session are exactly
        // the ones the user already tested. Fall back to the default browser if
        // Chrome is unavailable.
        tab.setPackage(CHROME_PACKAGE);
        try {
            startActivity(tab);
        } catch (ActivityNotFoundException noChrome) {
            tab.setPackage(null);
            startActivity(tab);
        }
    }
}
