allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// flutter_inappwebview_android 1.1.3 (latest stable) calls
// getDefaultProguardFile('proguard-android.txt'), which AGP 9 rejects. Patch its
// build script in the pub cache right before it is evaluated; a path
// dependency_override is not an option because pub cannot resolve paths under
// OneDrive. Remove once upstream ships a fix.
gradle.beforeProject {
    if (name == "flutter_inappwebview_android") {
        val script = buildFile
        val text = script.readText()
        val fixed = text.replace("'proguard-android.txt'", "'proguard-android-optimize.txt'")
        if (fixed != text) script.writeText(fixed)
    }
}

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
