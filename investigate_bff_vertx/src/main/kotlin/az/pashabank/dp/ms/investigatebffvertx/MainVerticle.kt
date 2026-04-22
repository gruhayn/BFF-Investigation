package az.pashabank.dp.ms.investigatebffvertx

import az.pashabank.dp.ms.investigatebffvertx.client.AddressClient
import az.pashabank.dp.ms.investigatebffvertx.client.BankAccountClient
import az.pashabank.dp.ms.investigatebffvertx.client.ContactClient
import az.pashabank.dp.ms.investigatebffvertx.client.CustomerClient
import az.pashabank.dp.ms.investigatebffvertx.client.DataStore
import az.pashabank.dp.ms.investigatebffvertx.client.HolderClient
import az.pashabank.dp.ms.investigatebffvertx.client.TransactionClient
import az.pashabank.dp.ms.investigatebffvertx.handler.AccountHandler
import az.pashabank.dp.ms.investigatebffvertx.handler.CustomerHandler
import az.pashabank.dp.ms.investigatebffvertx.handler.CustomerSummaryHandler
import az.pashabank.dp.ms.investigatebffvertx.service.AccountService
import az.pashabank.dp.ms.investigatebffvertx.service.CustomerService
import az.pashabank.dp.ms.investigatebffvertx.service.CustomerSummaryService
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import io.vertx.core.AbstractVerticle
import io.vertx.core.Promise
import io.vertx.core.json.jackson.DatabindCodec
import io.vertx.ext.web.Router
import io.vertx.ext.web.handler.BodyHandler
import org.slf4j.LoggerFactory
import java.lang.management.ManagementFactory

class MainVerticle : AbstractVerticle() {

    private val log = LoggerFactory.getLogger(MainVerticle::class.java)

    override fun start(startPromise: Promise<Void>) {
        DatabindCodec.mapper().registerKotlinModule()

        val dataStore = DataStore()
        val customerClient = CustomerClient(dataStore)
        val addressClient = AddressClient(dataStore)
        val bankAccountClient = BankAccountClient(dataStore)
        val contactClient = ContactClient(dataStore)
        val holderClient = HolderClient(dataStore)
        val transactionClient = TransactionClient(dataStore)

        val accountService = AccountService(customerClient, holderClient, transactionClient)
        val customerService = CustomerService(customerClient, addressClient, bankAccountClient, contactClient, transactionClient)
        val summaryService = CustomerSummaryService(customerClient, addressClient, bankAccountClient, contactClient, transactionClient)

        val accountHandler = AccountHandler(accountService, vertx)
        val customerHandler = CustomerHandler(customerService, vertx)
        val summaryHandler = CustomerSummaryHandler(summaryService, vertx)

        val router = Router.router(vertx)
        router.route().handler(BodyHandler.create())

        router.get("/accounts").handler { accountHandler.handle(it) }
        router.get("/customers").handler { customerHandler.handle(it) }
        router.get("/customer-summary").handler { summaryHandler.handle(it) }

        router.get("/health").handler { ctx ->
            ctx.response().putHeader("content-type", "application/json").end("""{"status":"UP"}""")
        }

        router.get("/memstats").handler { ctx ->
            val mem = ManagementFactory.getMemoryMXBean()
            val heap = mem.heapMemoryUsage
            val gcBeans = ManagementFactory.getGarbageCollectorMXBeans()
            val gcInfo = gcBeans.joinToString(",") { """{"name":"${it.name}","count":${it.collectionCount},"time":${it.collectionTime}}""" }
            ctx.response().putHeader("content-type", "application/json").end(
                """{"heapUsed":${heap.used},"heapMax":${heap.max},"heapCommitted":${heap.committed},"gc":[$gcInfo]}"""
            )
        }

        vertx.createHttpServer()
            .requestHandler(router)
            .listen(8083) { result ->
                if (result.succeeded()) {
                    log.info("Vert.x BFF started on port 8083")
                    startPromise.complete()
                } else {
                    startPromise.fail(result.cause())
                }
            }
    }
}
