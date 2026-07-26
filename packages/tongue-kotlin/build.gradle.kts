// Kotlin library for JVM and Android. Unlike emo-kotlin this is not an Android
// library (AAR) wrapping a Swift JNI native: the pipeline is a direct Kotlin port
// using only java.text.Normalizer and java.util.regex, so a plain jar works on
// both the JVM and Android with no native code, no NDK ABIs and no minSdk floor
// beyond what those two APIs need (both predate API 1). See ANDROID.md for the
// measurement behind that choice.
plugins {
    kotlin("jvm") version "2.1.0"
    `java-library`
    `maven-publish`
}

group = "ai.desertant"
version = "0.1.0"

kotlin {
    jvmToolchain(17)
    explicitApi()
}

dependencies {
    // Deliberately none. This artifact adds no transitive dependency to a consumer;
    // the metadata reader is hand-rolled for exactly that reason.
    testImplementation(kotlin("test"))
}

// The golden vectors are the cross-platform contract, so they run as the test task.
sourceSets {
    named("test") { resources.srcDir("src/test/resources") }
}

tasks.register<JavaExec>("goldenVectors") {
    description = "Replay golden/ through this port; the cross-platform contract."
    group = "verification"
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("ai.desertant.tongue.GoldenVectorTestKt")
}
tasks.named("check") { dependsOn("goldenVectors") }

publishing {
    publications.create<MavenPublication>("maven") {
        from(components["java"])
        pom {
            name.set("tongue")
            description.set(
                "On-device language identification for short text, across 83 languages. " +
                    "Pure Kotlin: no native code, no inference runtime."
            )
            url.set("https://github.com/Desert-Ant-Labs/tongue-kotlin")
            licenses {
                license {
                    name.set("Desert Ant Labs Source-Available License 1.0")
                    url.set("https://license.desertant.com/1.0")
                }
            }
        }
    }
}
