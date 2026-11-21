plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.elssoliman.midad"
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }

    defaultConfig {
        applicationId = "com.elssoliman.midad"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("evaluation") {
            storeFile = file("keystore/midad-evaluation.jks")
            storePassword = "midad-evaluation"
            keyAlias = "midad-evaluation"
            keyPassword = "midad-evaluation"
        }
        if (!System.getenv("MIDAD_KEYSTORE_FILE").isNullOrBlank()) {
            create("release") {
                storeFile = file(System.getenv("MIDAD_KEYSTORE_FILE"))
                storePassword = System.getenv("MIDAD_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("MIDAD_KEY_ALIAS")
                keyPassword = System.getenv("MIDAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            // Signing: private credentials from the environment win (CI secrets or a
            // local shell); otherwise the committed *evaluation* key is used so every
            // build is signed with the same key and can be installed over the last one.
            // The evaluation key is public by design and is not a production key.
            signingConfig = signingConfigs.getByName(
                if (System.getenv("MIDAD_KEYSTORE_FILE").isNullOrBlank()) "evaluation" else "release",
            )
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
