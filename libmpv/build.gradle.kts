import com.vanniktech.maven.publish.AndroidSingleVariantLibrary
import com.vanniktech.maven.publish.JavadocJar
import com.vanniktech.maven.publish.SourcesJar

plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.maven.publish)
}

android {
    namespace = "dev.jdtech.mpv"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = "30.0.16248370"

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("proguard-rules.pro")

        // Only these ABIs are packaged (and must have prebuilt native libs in
        // src/main/jniLibs, see buildscripts/build.sh). Defaults to the 32/64-bit ARM
        // ABIs used by signage players. Override with -Plibmpv.abis=arm64-v8a,
        // LIBMPV_ABIS, or gradle.properties, and keep it in sync with
        // LIBMPV_ARCHS for build.sh.
        val abis = (
            findProperty("libmpv.abis") as String?
                ?: providers.environmentVariable("LIBMPV_ABIS").orNull
                ?: "arm64-v8a,armeabi-v7a"
            )
            .split(",").map { it.trim() }.filter { it.isNotEmpty() }
        ndk {
            abiFilters += abis
        }
        externalNativeBuild {
            cmake {
                arguments += listOf(
                    "-DANDROID_STL=c++_shared",
                )
                cFlags += "-Werror"
                cppFlags += "-std=c++11"
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "4.1.2"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}

mavenPublishing {
    publishToMavenCentral(automaticRelease = true)
    signAllPublications()

    configure(
        platform = AndroidSingleVariantLibrary(
            javadocJar = JavadocJar.Empty(),
            sourcesJar = SourcesJar.Empty(),
            variant = "release",
        )
    )

    coordinates(
        groupId = "dev.jdtech.mpv",
        artifactId = "libmpv",
        version = "1.0.0"
    )

    pom {
        name = "libmpv-android"
        description = "libmpv for Android"
        inceptionYear = "2023"
        url = "https://github.com/jarnedemeulemeester/libmpv-android"
        licenses {
            license {
                name = "GNU General Public License v3.0 or later"
                url = "https://www.gnu.org/licenses/gpl-3.0.txt"
            }
        }
        developers {
            developer {
                id = "jarnedemeulemeester"
                name = "Jarne Demeulemeester"
                email = "jarnedemeulemeester@gmail.com"
            }
        }
        scm {
            url = "https://github.com/jarnedemeulemeester/libmpv-android.git"
            connection = "scm:git@github.com:jarnedemeulemeester/libmpv-android.git"
            developerConnection = "scm:git@github.com:jarnedemeulemeester/libmpv-android.git"
        }
        issueManagement {
            system = "GitHub"
            url = "https://github.com/jarnedemeulemeester/libmpv-android/issues"
        }
    }
}
