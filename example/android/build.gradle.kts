allprojects {
    repositories {
        mavenLocal()
        google()
        mavenCentral()
        maven {
            url = uri("https://zdrepo.jfrog.io/zdrepo/repo/")
            credentials {
                username = (project.findProperty("ARTIFACTORY_USERNAME") as String?) ?: System.getenv("ARTIFACTORY_USERNAME") ?: ""
                password = (project.findProperty("ARTIFACTORY_API_KEY") as String?) ?: System.getenv("ARTIFACTORY_API_KEY") ?: ""
            }
        }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
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
