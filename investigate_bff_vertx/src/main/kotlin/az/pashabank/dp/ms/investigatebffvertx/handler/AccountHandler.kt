package az.pashabank.dp.ms.investigatebffvertx.handler

import az.pashabank.dp.ms.investigatebffvertx.service.AccountService
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import io.vertx.core.Vertx
import io.vertx.ext.web.RoutingContext
import io.vertx.kotlin.coroutines.dispatcher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.slf4j.LoggerFactory

class AccountHandler(
    private val accountService: AccountService,
    private val vertx: Vertx,
) {
    private val log = LoggerFactory.getLogger(AccountHandler::class.java)
    private val mapper = jacksonObjectMapper()

    fun handle(ctx: RoutingContext) {
        val filterId = ctx.queryParam("filterId").firstOrNull()
        val filterBankName = ctx.queryParam("filterBankName").firstOrNull()
        val filterCurrency = ctx.queryParam("filterCurrency").firstOrNull()
        val search = ctx.queryParam("search").firstOrNull()
        val offset = ctx.queryParam("pageOffset").firstOrNull()?.toIntOrNull()?.takeIf { it >= 0 } ?: 0
        val limit = ctx.queryParam("pageLimit").firstOrNull()?.toIntOrNull()?.takeIf { it > 0 } ?: 10
        val includes = ctx.queryParam("include").firstOrNull()?.split(",")?.map { it.trim() }?.toSet() ?: emptySet()

        CoroutineScope(vertx.dispatcher()).launch {
            try {
                val result = accountService.getAccounts(filterId, filterBankName, filterCurrency, search, offset, limit, includes)
                ctx.response().putHeader("content-type", "application/json").end(mapper.writeValueAsString(result))
            } catch (e: Exception) {
                log.error("AccountHandler error", e)
                ctx.response().setStatusCode(500).end("""{"code":"vertx.internal-error","message":"${e.message}"}""")
            }
        }
    }
}
