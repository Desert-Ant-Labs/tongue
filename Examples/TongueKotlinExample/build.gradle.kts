// Runnable console example. `../../packages/tongue-kotlin` is included as a
// composite build, so this exercises the real published artifact rather than the
// source tree.
plugins {
    kotlin("jvm") version "2.1.0"
    application
}
kotlin { jvmToolchain(17) }
dependencies { implementation("ai.desertant:tongue") }
application { mainClass.set("MainKt") }
