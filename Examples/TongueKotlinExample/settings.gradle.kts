dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { mavenCentral() }
}
rootProject.name = "tongue-kotlin-example"
includeBuild("../../packages/tongue-kotlin") {
    dependencySubstitution { substitute(module("ai.desertant:tongue")).using(project(":")) }
}
