import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties").takeIf { it.exists() }
    ?: project.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.activewear.active_wear_scanning"
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
        applicationId = "com.activewear.active_wear_scanning"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "AWFL PROD")
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let {
                val fName = it as String
                val candidate1 = file(fName)
                val candidate2 = rootProject.file(fName)
                when {
                    candidate1.exists() -> candidate1
                    candidate2.exists() -> candidate2
                    else -> candidate1
                }
            }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    flavorDimensions += "default"

    productFlavors {
        create("uat") {
            dimension = "default"
            applicationIdSuffix = ".uat"
            resValue("string", "app_name", "AWFL UAT")
        }
        create("prod") {
            dimension = "default"
            resValue("string", "app_name", "AWFL PROD")
        }
        create("revamp") {
            dimension = "default"
            applicationIdSuffix = ".revamp"
            resValue("string", "app_name", "AWFL Revamp")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val flutterApkDir = File(rootProject.layout.buildDirectory.get().asFile, "app/outputs/flutter-apk")
        val uatApk = File(flutterApkDir, "app-uat-release.apk")
        val defaultReleaseApk = File(flutterApkDir, "app-release.apk")
        if (uatApk.exists()) {
            uatApk.copyTo(defaultReleaseApk, overwrite = true)
        }
    }
}

tasks.matching { it.name == "assembleDebug" }.configureEach {
    doLast {
        val flutterApkDir = File(rootProject.layout.buildDirectory.get().asFile, "app/outputs/flutter-apk")
        val uatDebugApk = File(flutterApkDir, "app-uat-debug.apk")
        val defaultDebugApk = File(flutterApkDir, "app-debug.apk")
        if (uatDebugApk.exists()) {
            uatDebugApk.copyTo(defaultDebugApk, overwrite = true)
        }
    }
}
