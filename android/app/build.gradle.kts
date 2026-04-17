import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val releaseStoreFilePath = keystoreProperties.getProperty("storeFile")
val releaseStoreFile = if (!releaseStoreFilePath.isNullOrBlank()) {
    rootProject.file(releaseStoreFilePath)
} else {
    null
}

val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (isReleaseBuildRequested) {
    if (!keystorePropertiesFile.exists()) {
        throw org.gradle.api.GradleException(
            "Missing android/key.properties. Configure a release keystore before building release artifacts."
        )
    }

    val missingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword").filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }

    if (missingKeys.isNotEmpty()) {
        throw org.gradle.api.GradleException(
            "android/key.properties is missing required keys: ${missingKeys.joinToString(", ")}."
        )
    }

    if (releaseStoreFile == null || !releaseStoreFile.exists()) {
        throw org.gradle.api.GradleException(
            "Release keystore not found at: ${releaseStoreFile?.absolutePath ?: "<missing storeFile path>"}."
        )
    }
}

android {
    namespace = "com.kense.bus_radar_driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.kense.bus_radar_driver"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists() && releaseStoreFile != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists() && releaseStoreFile != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
