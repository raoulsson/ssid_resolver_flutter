// <project>/android/settings.gradle.kts
pluginManagement {
    repositories {
        maven(url = "https://artifact.bytedance.com/repository/Volcengine/")
        maven(url = "https://storage.googleapis.com/download.flutter.io")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven(url = "https://artifact.bytedance.com/repository/Volcengine/")
        maven(url = "https://storage.googleapis.com/download.flutter.io")
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

rootProject.name = "ssid_resolver_flutter"

include(":app")
