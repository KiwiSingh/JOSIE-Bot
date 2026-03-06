plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.jetbrains.kotlin.android)
}

android {
    namespace = "com.josie.ai"
    compileSdk = 34

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
            externalNativeBuild {
                cmake {
                    cppFlags += "-std=c++17"
                    arguments += "-DGGML_VULKAN=OFF"
                    arguments += "-DANDROID_EMULATOR_BUILD=ON"
                }
            }
        }
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
            
            // Vulkan enabled for GPU-accelerated inference on real devices.
            // ARM dot-product and FP16 intrinsics give a significant additional
            // speedup on Snapdragon 8xx, Dimensity 9xxx, and Exynos 2xxx SoCs.
            externalNativeBuild {
                cmake {
                    // Note: -ffast-math is intentionally NOT used here.
                    // ggml's vec.h explicitly rejects -ffinite-math-only (implied by -ffast-math)
                    // because it uses NaN/Inf checks internally.
                    // Use -fno-finite-math-only instead,
                    // which still enables most fast-math optimizations safely.
                    cppFlags += "-std=c++17 -O3 -march=armv8-a+dotprod+fp16 -fno-finite-math-only"
                    arguments += "-DGGML_VULKAN=ON"
                    
                    // Dynamically routes glslc for macOS (local) or Ubuntu (GitHub Actions)
                    val glslcPath = System.getenv("GLSLC_PATH") ?: "/opt/homebrew/bin/glslc"
                    arguments += "-DVulkan_GLSLC_EXECUTABLE=$glslcPath"
                }
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