allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force every subproject (including third-party Flutter plugins like
// receive_sharing_intent that still ship with stale JVM targets) onto
// Java/Kotlin 17. Without this, mixed jvmTargets crash the release build.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { android ->
            try {
                val compileOptions = android.javaClass
                    .getMethod("getCompileOptions")
                    .invoke(android)
                val setSource = compileOptions.javaClass
                    .getMethod("setSourceCompatibility", JavaVersion::class.java)
                val setTarget = compileOptions.javaClass
                    .getMethod("setTargetCompatibility", JavaVersion::class.java)
                setSource.invoke(compileOptions, JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, JavaVersion.VERSION_17)
            } catch (_: Throwable) { /* not an Android module */ }
        }
        tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
