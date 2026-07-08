
// Forza compileSdk 36 su tutti i moduli Android (plugin inclusi).
// Alcuni plugin (es. flutter_plugin_android_lifecycle via file_picker)
// richiedono compileSdk >= 36. Appeso in CI a android/build.gradle.kts.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            (ext as com.android.build.gradle.BaseExtension).compileSdkVersion(36)
        }
    }
}
