plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Flutter Gradle plugin (must be last)
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ── Release signing (Play Store) — аз android/key.properties хонда мешавад.
// Агар key.properties набошад, RELEASE BUILD ШИКАСТ МЕХӮРАД (debug fallback НЕСТ).
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.raonson.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.raonson.app"
        minSdk = 23
        targetSdk = 36

        // versionCode худкор аз CI (APP_VERSION_CODE) — ҳамеша беназир ва
        // афзоянда, то дигар "version code already used" набошад.
        versionCode = (System.getenv("APP_VERSION_CODE")?.toIntOrNull()) ?: 100
        versionName = System.getenv("APP_VERSION_NAME") ?: "1.1.0"
    }

    compileOptions {
        // flutter_local_notifications талаб мекунад — бе ин build шикаст мехӯрад.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ✅ Correct replacement for deprecated kotlinOptions
    kotlin {
        compilerOptions {
            jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            )
        }
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                null
            // R8 + хурдкунии resource — ҳаҷми APK/AAB-ро ба таври ҷиддӣ кам
            // мекунад ва иҷроро тезтар мекунад.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Ҳар ABI APK-и ҷудогона (барои тест берун аз Play хурдтар);
    // дар AAB Play худаш тақсим мекунад.
    //
    // ⚠️ Агар `flutter build apk --split-per-abi` даъват шавад,
    // ин блок ба он ДАСТ НАМЕРАСОНАД.
    //
    // Чаро: Flutter худаш `splits.abi`-ро фаъол мекунад. Баъд ин
    // блок иҷро мешуд ва онро ХОМӮШ мекард (чун `SPLIT_PER_ABI`
    // набуд). Дар натиҷа як output-и бе ABI мемонд, вале плагини
    // Flutter ҳанӯз гумон мекард, ки тақсим фаъол аст:
    //
    //   flutter.groovy:1182
    //   int abiVersionCode = ABI_VERSION.get(output.getFilter(ABI))
    //
    // `get(null)` → `null`, ва рехтани `null` ба `int` мепартояд:
    //
    //   GroovyCastException: Cannot cast object 'null' ... to int
    //
    // (Сатри навбатии худи Flutter `if (abiVersionCode != null)`
    // аст — яъне он ин ҳолатро пешбинӣ кардааст, вале эълони `int`
    // пеш аз он мепартояд. Ин камбудии худи плагин аст.)
    val flutterHandlesSplit =
        (project.findProperty("split-per-abi") as String?)?.toBoolean() ?: false

    if (!flutterHandlesSplit) {
        splits {
            abi {
                isEnable = (System.getenv("SPLIT_PER_ABI") == "true")
                reset()
                include("armeabi-v7a", "arm64-v8a")
                isUniversalApk = false
            }
        }
    }
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release") } && !hasReleaseKeystore) {
        throw GradleException(
            "Release keystore not found! Create android/key.properties with " +
            "storeFile, storePassword, keyAlias, keyPassword. " +
            "Production release MUST NOT use debug signing."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring — flutter_local_notifications-ро дастгирӣ мекунад.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
