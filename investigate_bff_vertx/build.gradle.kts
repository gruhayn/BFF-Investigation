import com.github.jengelman.gradle.plugins.shadow.tasks.ShadowJar

plugins {
    kotlin("jvm") version "1.9.22"
    id("com.github.johnrengelman.shadow") version "8.1.1"
    application
}

group = "az.pashabank.dp"
version = "0.0.1"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

val vertxVersion = "4.5.4"
val coroutinesVersion = "1.8.0"

dependencies {
    implementation("io.vertx:vertx-web:$vertxVersion")
    implementation("io.vertx:vertx-lang-kotlin:$vertxVersion")
    implementation("io.vertx:vertx-lang-kotlin-coroutines:$vertxVersion")
    implementation("io.vertx:vertx-core:$vertxVersion")
    implementation("io.vertx:vertx-health-check:$vertxVersion")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin:2.16.1")
    implementation("com.fasterxml.jackson.core:jackson-databind:2.16.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:$coroutinesVersion")
    implementation("org.jetbrains.kotlin:kotlin-reflect:1.9.22")
    implementation("ch.qos.logback:logback-classic:1.4.14")
    implementation("org.slf4j:slf4j-api:2.0.9")
    implementation("net.logstash.logback:logstash-logback-encoder:8.0")
}

application {
    mainClass.set("az.pashabank.dp.ms.investigatebffvertx.MainKt")
}

tasks.withType<ShadowJar> {
    archiveFileName = "investigate-bff-vertx.jar"
    manifest {
        attributes["Main-Class"] = "az.pashabank.dp.ms.investigatebffvertx.MainKt"
    }
    mergeServiceFiles()
}

kotlin {
    compilerOptions {
        freeCompilerArgs.addAll("-Xjsr305=strict")
    }
}

tasks.withType<Test> {
    useJUnitPlatform()
}
