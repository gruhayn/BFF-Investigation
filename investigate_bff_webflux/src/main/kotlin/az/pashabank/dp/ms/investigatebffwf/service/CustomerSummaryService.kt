package az.pashabank.dp.ms.investigatebffwf.service

import az.pashabank.dp.ms.investigatebffwf.client.AddressClient
import az.pashabank.dp.ms.investigatebffwf.client.BankAccountClient
import az.pashabank.dp.ms.investigatebffwf.client.ContactClient
import az.pashabank.dp.ms.investigatebffwf.client.CustomerClient
import az.pashabank.dp.ms.investigatebffwf.client.TransactionClient
import az.pashabank.dp.ms.investigatebffwf.exception.NotFoundException
import az.pashabank.dp.ms.investigatebffwf.mapper.CustomerSummaryMapper
import az.pashabank.dp.ms.investigatebffwf.model.CustomerFilter
import az.pashabank.dp.ms.investigatebffwf.model.CustomerSummary
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import reactor.core.publisher.Mono

@Service
class CustomerSummaryService(
    private val customerClient: CustomerClient,
    private val addressClient: AddressClient,
    private val bankAccountClient: BankAccountClient,
    private val contactClient: ContactClient,
    private val transactionClient: TransactionClient,
    private val summaryMapper: CustomerSummaryMapper,
) {
    private val log = LoggerFactory.getLogger(CustomerSummaryService::class.java)

    fun getCustomerSummary(customerId: String): Mono<CustomerSummary> {
        log.info("ActionLog.getCustomerSummary.start customerId={}", customerId)
        val ids = listOf(customerId)

        // Fire 4 calls concurrently using Mono.zip
        return Mono.zip(
            customerClient.fetchCustomers(CustomerFilter(id = customerId)),
            addressClient.getByCustomerIds(ids).onErrorReturn(emptyMap()),
            bankAccountClient.getByCustomerIds(ids).onErrorReturn(emptyMap()),
            contactClient.getByCustomerIds(ids).onErrorReturn(emptyMap()),
        ).flatMap { tuple ->
            val customers = tuple.t1
            if (customers.isEmpty()) {
                return@flatMap Mono.error(NotFoundException("investigate-bff-wf.customer.not-found", "Customer not found"))
            }
            val customer = customers.first()
            val addressMap = tuple.t2
            val accountMap = tuple.t3
            val contactMap = tuple.t4
            val accounts = accountMap[customerId].orEmpty()

            log.info(
                "ActionLog.getCustomerSummary.collected addresses={} accounts={} contacts={}",
                addressMap[customerId]?.size ?: 0, accounts.size, contactMap[customerId]?.size ?: 0,
            )

            // Second wave: fetch transactions
            val accountIds = accounts.map { it.id }
            val txnMono = if (accountIds.isNotEmpty()) {
                transactionClient.getByAccountIds(accountIds).onErrorReturn(emptyMap())
            } else {
                Mono.just(emptyMap())
            }

            txnMono.map { txnMap ->
                summaryMapper.mapSummary(
                    customer = customer,
                    addresses = addressMap[customerId].orEmpty(),
                    accounts = accounts,
                    txnsByAccount = txnMap,
                    contacts = contactMap[customerId].orEmpty(),
                )
            }
        }.doOnSuccess { log.info("ActionLog.getCustomerSummary.end") }
    }
}
