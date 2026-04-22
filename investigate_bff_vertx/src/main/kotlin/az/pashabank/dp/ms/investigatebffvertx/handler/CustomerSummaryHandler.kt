package az.pashabank.dp.ms.investigatebffvertx.handler

import az.pashabank.dp.ms.investigatebffvertx.service.CustomerSummaryService
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import io.vertx.core.Vertx
import io.vertx.ext.web.RoutingContext
import io.vertx.kotlin.coroutines.dispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.slf4j.LoggerFactory

class CustomerSummaryHandler(
    private val customerSummaryService: CustomerSummaryService,
    private val vertx: Vertx,
) {
    private val log = LoggerFactory.getLogger(CustomerSummaryHandler::class.java)
    private val mapper = jacksonObjectMapper()

    fun handle(ctx: RoutingContext) {
        val customerId = ctx.queryParam("id").firstOrNull()
        if (customerId.isNullOrBlank()) {
            ctx.response().setStatusCode(400).end("""{"code":"vertx.validation","message":"id query parameter is required"}""")
            return
        }

        CoroutineScope(vertx.dispatcher()).launch {
            try {
                val result = customerSummaryService.getCustomerSummary(customerId)
                ctx.response().putHeader("content-type", "application/json").end(mapper.writeValueAsString(result))
            } catch (e: IllegalArgumentException) {
                ctx.response().setStatusCode(404).end("""{"code":"vertx.not-found","message":"${e.message}"}""")
            } catch (e: Exception) {
                log.error("CustomerSummaryHandler error", e)
                ctx.response().setStatusCode(500).end("""{"code":"vertx.internal-error","message":"${e.message}"}""")
            }
        }
    }
}
