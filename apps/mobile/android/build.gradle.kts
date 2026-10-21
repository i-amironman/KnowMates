import com.android.build.gradle.LibraryExtension

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

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ponytail: old plugins (e.g. flutter_webrtc) set compileSdk 31 in their own build.gradle after the plugin applies
subprojects {
    val bumpLibraryCompileSdk = {
        extensions.findByType(LibraryExtension::class.java)?.compileSdk = 36
    }
    if (state.executed) {
        bumpLibraryCompileSdk()
    } else {
        afterEvaluate { bumpLibraryCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
