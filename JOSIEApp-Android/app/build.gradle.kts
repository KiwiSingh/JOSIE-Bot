plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.jetbrains.kotlin.android)
}

android {
    namespace = "com.josie.ai"
    compileSdk = 34
    lint {
    checkReleaseBuilds = false
}

    defaultConfig {
        applicationId = "com.josie.ai"
        // minSdk 29 required for Vulkan 1.1 — vkGetPhysicalDeviceFeatures2 and related
        // entrypoints used by ggml-vulkan are not exported by the NDK's libvulkan.so
        // stub until API level 29. API 26 only covers Vulkan 1.0.
        minSdk = 29
        targetSdk = 34
        versionCode = 2
        versionName = "1.1"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }

        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_PATH") ?: "kiwi.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        debug {
            // Vulkan is disabled for AVD/emulator stability.
            // CPU-only inference is expected to be slow on emulators — this is unavoidable.
            // WARNING: do not sideload this variant on a real device and expect GPU acceleration.
            externalNativeBuild {
                cmake {
                    cppFlags += "-std=c++17"
                    arguments += "-DGGML_VULKAN=OFF"
                    arguments += "-DCMAKE_BUILD_TYPE=Debug"
                    arguments += "-DANDROID_EMULATOR_BUILD=ON"
                }
            }
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release") [cite: 14]

            externalNativeBuild {
                cmake {
                    cppFlags += "-std=c++17 -O3 -march=armv8-a+dotprod+fp16 -fno-finite-math-only" [cite: 19]
                    arguments += "-DGGML_VULKAN=ON"
                    arguments += "-DCMAKE_BUILD_TYPE=Release"
                    arguments += "-DCMAKE_CXX_FLAGS_RELEASE=-O3 -DNDEBUG"

                    // --- THE FIX: Robust NDK Shader Compiler Pathing ---
                    // This detects if we are on your Mac (darwin) or GitHub Actions (linux)
                    // and uses the compiler bundled with the Android NDK.
                    val ndkDir = android.ndkDirectory.absolutePath
                    val osName = System.getProperty("os.name").lowercase()
                    val hostTag = if (osName.contains("mac")) "darwin-x86_64" else "linux-x86_64"
                    val glslcPath = "$ndkDir/shader-tools/$hostTag/glslc"
                    
                    arguments += "-DVulkan_GLSLC_EXECUTABLE=$glslcPath"
                }
            }
            
            ndk {
                debugSymbolLevel = "NONE" [cite: 22]
            }
}
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.11"
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.okhttp)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}