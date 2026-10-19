plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingValues = listOf("ANDROID_KEYSTORE_PATH", "ANDROID_KEYSTORE_PASSWORD", "ANDROID_KEY_ALIAS", "ANDROID_KEY_PASSWORD").associateWith { System.getenv(it) }

gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        check(signingValues.values.all { !it.isNullOrBlank() }) {
            "安卓发布缺少固定签名配置，参见 docs/android-signing.md。"
        }
        check(file(signingValues.getValue("ANDROID_KEYSTORE_PATH")!!).isFile) {
            "安卓发布签名密钥文件不存在。"
        }
    }
}

android {
    namespace = "com.example.comic"
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
        applicationId = "com.example.comic"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            signingValues["ANDROID_KEYSTORE_PATH"]?.takeIf { it.isNotBlank() }?.let { storeFile = file(it) }
            storePassword = signingValues["ANDROID_KEYSTORE_PASSWORD"]
            keyAlias = signingValues["ANDROID_KEY_ALIAS"]
            keyPassword = signingValues["ANDROID_KEY_PASSWORD"]
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
