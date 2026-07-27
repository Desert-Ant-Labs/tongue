pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        // Before ai.desertant:tongue is on Central, `mise run publish-android` with
        // no credentials publishes to ~/.m2 and this resolves from there. Harmless
        // afterwards: a released version is found either way.
        mavenLocal()
        google()
        mavenCentral()
    }
}

rootProject.name = "TongueAndroidExample"
include(":app")
