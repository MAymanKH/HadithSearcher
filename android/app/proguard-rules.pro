# Plugin consumer rules and Flutter's bundled rules preserve the classes used
# by this app. Avoid retaining unused Play delivery code from the embedding.

# This app never registers push subscriptions. Fold out PostHog's optional
# Firebase integration, including its reference to the Play Services listener.
-assumevalues class com.posthog.android.PostHogAndroidConfig {
    public boolean getCapturePushNotificationSubscriptions() return false;
}
