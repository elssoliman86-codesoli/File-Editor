allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val buildDirectory = layout.buildDirectory
rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))
subprojects {
    layout.buildDirectory.value(rootProject.layout.buildDirectory.get().dir("project/$name"))
}

// AGP uses this file to remove stale build metadata.
tasks.register<Delete>("clean") { delete(buildDirectory) }
