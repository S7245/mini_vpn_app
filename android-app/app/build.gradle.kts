plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.minivpn.app"
    compileSdk = 35
    // Pin to an already-installed build-tools so AGP does NOT auto-download
    // build-tools;34.0.0 — that download hit flaky-link ZipFile corruption in
    // the FFI spike (FINDINGS §9). 35.0.1 / 36.0.0 are present locally.
    buildToolsVersion = "35.0.1"

    defaultConfig {
        applicationId = "com.minivpn.app"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "0.1"
        // Phase 2 ships arm64 only (matches the cross-compiled rust-core .so and
        // the arm64 AVD). Add more ABIs when CI/device coverage needs them.
        ndk { abiFilters += "arm64-v8a" }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures { compose = true }

    buildTypes {
        getByName("debug") { isMinifyEnabled = false }
    }
}

dependencies {
    // rust-core over FFI: JNA is the UniFFI Kotlin runtime. On Android it MUST
    // be the AAR (bundles JNA's native dispatch .so per ABI; the plain jar fails
    // to load — FINDINGS §9).
    implementation("net.java.dev.jna:jna:5.14.0@aar")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // Compose (Material 3). BOM keeps the artifact versions aligned.
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.ui:ui-tooling-preview")
    debugImplementation("androidx.compose.ui:ui-tooling")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}
