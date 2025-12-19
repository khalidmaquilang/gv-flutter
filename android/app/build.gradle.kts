import org.gradle.api.tasks.Copy

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.test_flutter"
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
        applicationId = "com.example.test_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    packaging {
        jniLibs {
            pickFirst("**/libaosl.so")
        }
    }
}

flutter {
    source = "../.."
}

val bnbSdkVersion: String = rootProject.extra["bnb_sdk_version"] as String

dependencies {
    implementation("com.banuba.sdk:face_tracker:$bnbSdkVersion")
    implementation("com.banuba.sdk:background:$bnbSdkVersion")
}

val copyEffects by tasks.registering(Copy::class) {
    from("${flutter.source}/effects")
    into("src/main/assets/gv-resources/effects")
    inputs.dir("${flutter.source}/effects")
    outputs.dir("src/main/assets/gv-resources/effects")
}

tasks.named("preBuild") {
    dependsOn(copyEffects)
}