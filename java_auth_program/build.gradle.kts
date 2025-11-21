plugins {
    id("java")
    id("application")
    id("org.graalvm.buildtools.native") version "0.11.3"
}

group = "ee.ut.kipp"
version = "0.0.1-SNAPSHOT"

application {
    mainClass.set("ee.ut.kipp.Main")
}

graalvmNative {
    binaries {
        all {
            verbose.set(true)

            javaLauncher.set(
                javaToolchains.launcherFor {
                    languageVersion.set(JavaLanguageVersion.of(25))
                    vendor.set(JvmVendorSpec.GRAAL_VM)
                }
            )
        }

        named("main") {
            imageName.set("JavaAuthProgram")
            mainClass.set(application.mainClass.get())
            buildArgs.add("--enable-url-protocols=https")
            // buildArgs.add("-O3")
            // buildArgs.add("--no-fallback")
        }

        named("test") {
            quickBuild.set(true)
            debug.set(true)
        }
    }
}

tasks.register<Jar>("fatJar") {
    archiveClassifier.set("all")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE

    from(sourceSets.main.get().output)

    from({
        configurations.runtimeClasspath.get().filter { it.name.endsWith("jar") }.map { zipTree(it) }
    }) {
        // Exclude signature files
        exclude("META-INF/*.SF", "META-INF/*.DSA", "META-INF/*.RSA")
    }

    manifest {
        attributes(
            "Main-Class" to "ee.ut.kipp.Main"
        )
    }
}

repositories {
    mavenCentral()
    maven {
        url = uri("https://gitlab.com/api/v4/projects/19948337/packages/maven")
    }
}

dependencies {

    implementation("eu.webeid.security:authtoken-validation:3.2.0")

    // Silence all logging messages
    runtimeOnly("org.slf4j:slf4j-nop:2.1.0-alpha1")

    testImplementation(platform("org.junit:junit-bom:5.10.0"))
    testImplementation("org.junit.jupiter:junit-jupiter")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.test {
    useJUnitPlatform()
}
