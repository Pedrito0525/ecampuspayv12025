import com.android.build.gradle.BaseExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    
    // Configure all Android subprojects to use compileSdk 35
    plugins.withId("com.android.library") {
        extensions.configure<BaseExtension> {
            compileSdkVersion(35)
        }
    }
    plugins.withId("com.android.application") {
        extensions.configure<BaseExtension> {
            compileSdkVersion(35)
        }
    }
    
    // Also configure for Flutter plugins that apply Android plugin dynamically
    afterEvaluate {
        try {
            extensions.findByType<BaseExtension>()?.apply {
                compileSdkVersion(35)
            }
        } catch (e: Exception) {
            // Ignore if not an Android project or already configured
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
