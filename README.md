
## Google Maps API Key (Android)

AndroidManifest içindeki `com.google.android.geo.API_KEY` artık hard-code değil; Gradle `manifestPlaceholders` ile build sırasında enjekte edilir.

Key'i şu kaynaklardan biriyle verebilirsin (öncelik sırası):

1) Ortam değişkeni: `GOOGLE_MAPS_API_KEY`

2) Proje kökünde `.env` dosyası:

```
GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

3) `android/local.properties` içine:

```
GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

Not: `.env` ve `local.properties` genelde git'e eklenmez.
