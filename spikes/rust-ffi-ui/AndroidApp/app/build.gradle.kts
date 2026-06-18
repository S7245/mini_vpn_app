plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.spike.ffi"
    compileSdk = 35
    // Pin to an already-installed build-tools (35.0.1 / 36.0.0 present) so AGP
    // does NOT auto-download build-tools;34.0.0 — that download hit the same
    // flaky-link ZipFile corruption as the NDK/sdkmanager downloads.
    buildToolsVersion = "35.0.1"

    defaultConfig {
        applicationId = "com.spike.ffi"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"
        ndk { abiFilters += "arm64-v8a" }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildTypes {
        getByName("debug") { isMinifyEnabled = false }
    }
}

dependencies {
    // JNA on Android requires the AAR (bundles the JNA native dispatch .so per ABI).
    implementation("net.java.dev.jna:jna:5.14.0@aar")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
