package az.pashabank.dp.ms.investigatebffvertx.handler

import az.pashabank.dp.ms.investigatebffvertx.service.CustomerService
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import io.vertx.core.Vertx
import io.vertx.ext.web.RoutingContext
import io.vertx.kotlin.coroutines.dispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.slf4j.LoggerFactory

class CustomerHandler(
    private val customerService: CustomerService,
    private val vertx: Vertx,
) {
    private val log = LoggerFactory.getLogger(CustomerHandler::class.java)
    private val mapper = jacksonObjectMapper()

    fun handle(ctx: RoutingContext) {
        val filterId = ctx.queryParam("filterId").firstOrNull()
        val filterName = ctx.queryParam("filterName").firstOrNull()
        val filterEmail = ctx.queryParam("filterEmail").firstOrNull()
        val search = ctx.queryParam("search").firstOrNull()
        val offset = ctx.queryParam("pageOffset").firstOrNull()?.toIntOrNull()?.takeIf { it >= 0 } ?: 0
        val limit = ctx.queryParam("pageLimit").firstOrNull()?.toIntOrNull()?.takeIf { it > 0 } ?: 10
        val includes = ctx.queryParam("include").firstOrNull()?.split(",")?.map { it.trim() }?.toSet() ?: emptySet()

        CoroutineScope(vertx.dispatcher()).launch {
            try {
                val result = customerService.getCustomers(filterId, filterName, filterEmail, search, offset, limit, includes)
                ctx.response().putHeader("content-type", "application/json").end(mapper.writeValueAsString(result))
            } catch (e: Exception) {
                log.error("CustomerHandler error", e)
                ctx.response().setStatusCode(500).end("""{"code":"vertx.internal-error","message":"${e.message}"}""")
            }
        }
    }
}
