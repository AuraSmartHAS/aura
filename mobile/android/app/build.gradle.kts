import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave do Google Maps: android/local.properties (ignorado pelo git) e, na falta,
// a variavel de ambiente GOOGLE_MAPS_API_KEY (CI). Vazia nao quebra o build:
// o mapa apenas abre sem tiles.
val mapsApiKey: String = run {
    val localProperties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { localProperties.load(it) }
    }
    localProperties.getProperty("GOOGLE_MAPS_API_KEY")?.trim()?.takeIf { it.isNotEmpty() }
        ?: System.getenv("GOOGLE_MAPS_API_KEY")?.trim()?.takeIf { it.isNotEmpty() }
        ?: ""
}
if (mapsApiKey.isEmpty()) {
    logger.warn(
        "AVISO: GOOGLE_MAPS_API_KEY nao definida (android/local.properties ou variavel " +
            "de ambiente). O build segue, mas o mapa da entrega abre sem tiles.",
    )
}

android {
    namespace = "com.example.aura"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.aura"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect (health package) requires API 26+.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
