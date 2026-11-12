plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.nightfall.game"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.nightfall.game"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
    }

    flavorDimensions += "abi"

    productFlavors {
        create("arm32") {
            dimension = "abi"
            ndk {
                abiFilters += listOf("armeabi-v7a", "x86")
            }
        }

        create("arm64") {
            dimension = "abi"
            ndk {
                abiFilters += listOf("arm64-v8a", "x86_64")
            }
        }

        create("play") {
            dimension = "abi"
            ndk {
                abiFilters += listOf(
                    "armeabi-v7a",
                    "arm64-v8a",
                    "x86",
                    "x86_64"
                )
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    androidResources {
        ignoreAssetsPattern = "!.svn:!.git:!.gitignore:!.ds_store:!*.scc:<dir>_*:!CVS:!thumbs.db:!picasa.ini:!*~"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("org.godotengine:godot:4.3.0.stable")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.fragment:fragment-ktx:1.7.1")
}
