package com.kirmatas.game;

import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import androidx.core.splashscreen.SplashScreen;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    SplashScreen.installSplashScreen(this);
    super.onCreate(savedInstanceState);
    lockOffline();
  }

  @Override
  public void onStart() {
    super.onStart();
    lockOffline();
    focusWeb();
  }

  @Override
  public void onResume() {
    super.onResume();
    lockOffline();
    focusWeb();
  }

  private void lockOffline() {
    try {
      if (getBridge() == null) return;
      WebView w = getBridge().getWebView();
      if (w == null) return;
      WebSettings s = w.getSettings();
      s.setBlockNetworkLoads(true);
      s.setBlockNetworkImage(true);
      s.setJavaScriptCanOpenWindowsAutomatically(false);
    } catch (Exception ignored) {}
  }

  private void focusWeb() {
    try {
      if (getBridge() == null) return;
      WebView w = getBridge().getWebView();
      if (w == null) return;
      w.setFocusable(true);
      w.setFocusableInTouchMode(true);
      w.setClickable(true);
      w.requestFocus();
    } catch (Exception ignored) {}
  }
}
