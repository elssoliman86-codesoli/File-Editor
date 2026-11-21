allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val buildDirectory = layout.buildDirectory
rootProject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build"))
subprojects {
    // Flutter looks for the APK at <repo>/build/app/outputs/flutter-apk, so each
    // subproject must build into <repo>/build/<name> (no extra directory level).
    layout.buildDirectory.value(rootProject.layout.buildDirectory.get().dir(name))
}

subprojects {
    // Plugin projects (e.g. android_file_picker) read the `flutter` extension,
    // which the Flutter Gradle plugin adds while :app is configured. Gradle
    // evaluates subprojects alphabetically, so force :app first.
    project.evaluationDependsOn(":app")
}

// AGP uses this file to remove stale build metadata.
tasks.register<Delete>("clean") { delete(buildDirectory) }
