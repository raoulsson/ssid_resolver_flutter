// <project>/android/build.gradle.kts
//plugins {
//    id("com.android.library") version "8.8.0"
//    id("org.jetbrains.kotlin.android") version "2.1.0"
//}
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

//repositories {
//    maven(url = "https://artifact.bytedance.com/repository/Volcengine/")
//    maven(url = "https://storage.googleapis.com/download.flutter.io")
//    google()
//    mavenCentral()
//}

android {
    namespace = "com.raoulsson.ssid_resolver_flutter"
    compileSdk = 34

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 17
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        signingConfig = signingConfigs.getByName("debug")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.1")
    compileOnly("io.flutter:flutter_embedding_debug:1.0.0")
    compileOnly("io.flutter:flutter_embedding_release:1.0.0")
    testImplementation("io.flutter:flutter_embedding_debug:1.0.0")
    testImplementation("org.jetbrains.kotlin:kotlin-test:2.1.0")
    testImplementation("org.mockito:mockito-core:5.15.2")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.4.0")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
}

project.version = "0.0.1"


