// Kotlin library for JVM and Android. Unlike emo-kotlin this is not an Android
// library (AAR) wrapping a Swift JNI native: the pipeline is a direct Kotlin port
// using only java.text.Normalizer and java.util.regex, so a plain jar works on
// both the JVM and Android with no native code, no NDK ABIs and no minSdk floor
// beyond what those two APIs need (both predate API 1). See ANDROID.md for the
// measurement behind that choice.
//
// That is also why the shared ai.desertant.model-sdk convention plugin is not
// applied here. It applies com.android.library, pins compileSdk 35 / minSdk 24,
// fixes the NDK abiFilters to arm64-v8a and x86_64, wires `mise run
// android-natives` into preBuild and takes a project dependency on
// :<model>-tflite-resources. This model has no native library, no tflite and no
// Android-only surface, so that convention would replace a jar that runs
// everywhere with an AAR that needs the Android SDK to build.
//
// The half that does apply is the publish convention, reproduced below verbatim
// from desertAntPom + ModelSdkPlugin so the coordinates, signing, sources and
// javadoc jars and POM come out identical to every other Desert Ant artifact.
import com.vanniktech.maven.publish.JavadocJar
import com.vanniktech.maven.publish.KotlinJvm

plugins {
    kotlin("jvm") version "2.1.21"
    `java-library`
    id("com.vanniktech.maven.publish") version "0.34.0"
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

// src/test/resources is already a test resource root by convention; re-adding it
// makes processTestResources see every vector file twice and fail on duplicates.

tasks.register<JavaExec>("goldenVectors") {
    description = "Replay golden/ through this port; the cross-platform contract."
    group = "verification"
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("ai.desertant.tongue.GoldenVectorTestKt")
}
tasks.named("check") { dependsOn("goldenVectors") }

val repoUrl = "https://github.com/Desert-Ant-Labs/${rootProject.name}"

mavenPublishing {
    configure(KotlinJvm(javadocJar = JavadocJar.Javadoc(), sourcesJar = true))
    publishToMavenCentral()
    // Signing keys only exist on a release runner; without them `build` and
    // `publishToMavenLocal` still work, which is what CI runs.
    if (providers.gradleProperty("signingInMemoryKey").isPresent) signAllPublications()
    pom {
        name.set(rootProject.name.replaceFirstChar { it.uppercase() })
        description.set(
            "On-device language identification for short text, across 83 languages. " +
                "Pure Kotlin: no native code and no inference runtime."
        )
        url.set(repoUrl)
        licenses {
            license {
                name.set("Desert Ant Labs Source-Available License 1.0")
                url.set("https://license.desertant.com/1.0")
                distribution.set("repo")
            }
        }
        developers {
            developer {
                id.set("desert-ant-labs")
                name.set("Desert Ant Labs")
                email.set("contact@desertant.com")
                url.set("https://desertant.com")
            }
        }
        scm {
            url.set(repoUrl)
            connection.set("scm:git:git://github.com/Desert-Ant-Labs/${rootProject.name}.git")
            developerConnection.set("scm:git:ssh://git@github.com/Desert-Ant-Labs/${rootProject.name}.git")
        }
    }
}
