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

subprojects {
    // The release-time "lint vital" check crashes inside Android Lint itself
    // (NoSuchMethodError in its Java doc parser) on some plugin sources, e.g.
    // image_picker_android. It only duplicates `flutter analyze`, so skip it.
    tasks.configureEach {
        if (name.startsWith("lintVital")) enabled = false
    }
}

// AGP uses this file to remove stale build metadata.
tasks.register<Delete>("clean") { delete(buildDirectory) }
