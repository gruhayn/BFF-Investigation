package az.pashabank.dp.ms.investigatebffvertx

import io.vertx.core.Vertx

fun main() {
    val vertx = Vertx.vertx()
    vertx.deployVerticle(MainVerticle()) { result ->
        if (result.failed()) {
            System.err.println("Failed to deploy verticle: ${result.cause().message}")
            vertx.close()
        }
    }
}
