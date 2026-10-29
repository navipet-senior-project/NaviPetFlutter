plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Unity AR is optional. NaviPetUnity's tools/build-indoor-ar-aar.sh fills the
// gitignored android/unity-ar/; CI and most machines build without it.
val unityArDir = rootProject.file("unity-ar")
val unityArEnabled = unityArDir.resolve("unityLibrary-release.aar").isFile

android {
    namespace = "com.navipet.navipet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.navipet.navipet"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // The Unity AAR declares minSdk 26. A lower app value fails the manifest merge.
        minSdk = if (unityArEnabled) maxOf(flutter.minSdkVersion, 26) else flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("boolean", "UNITY_AR_ENABLED", unityArEnabled.toString())
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    if (unityArEnabled) {
        // Build-type source sets each carry their own manifest, so the Unity
        // host is merged in only when the Unity library is present.
        buildTypes.all {
            sourceSets.maybeCreate(name).apply {
                manifest.srcFile("src/unity/AndroidManifest.xml")
                java.srcDir("src/unity/kotlin")
                res.srcDir("src/unity/res")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    if (unityArEnabled) {
        implementation(fileTree(mapOf("dir" to unityArDir, "include" to listOf("*.aar"))))
        // Remote dependencies the Unity Gradle modules declare, listed by the build script.
        unityArDir.resolve("maven-deps.txt").takeIf { it.isFile }?.readLines()
            ?.map { it.trim() }?.filter { it.isNotEmpty() }
            ?.forEach { implementation(it) }
    }
}
