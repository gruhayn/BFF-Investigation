package az.pashabank.dp.ms.investigatebff.service

import az.pashabank.dp.ms.investigatebff.client.AddressClient
import az.pashabank.dp.ms.investigatebff.client.BankAccountClient
import az.pashabank.dp.ms.investigatebff.client.ContactClient
import az.pashabank.dp.ms.investigatebff.client.CustomerClient
import az.pashabank.dp.ms.investigatebff.client.TransactionClient
import az.pashabank.dp.ms.investigatebff.exception.NotFoundException
import az.pashabank.dp.ms.investigatebff.mapper.CustomerSummaryMapper
import az.pashabank.dp.ms.investigatebff.model.CustomerFilter
import az.pashabank.dp.ms.investigatebff.model.CustomerSummary
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.util.concurrent.CompletableFuture

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

    fun getCustomerSummary(customerId: String): CustomerSummary {
        log.info("ActionLog.getCustomerSummary.start customerId={}", customerId)
        val ids = listOf(customerId)

        // Fire 4 client calls concurrently
        val customersFuture = CompletableFuture.supplyAsync {
            customerClient.fetchCustomers(CustomerFilter(id = customerId))
        }
        val addressesFuture = CompletableFuture.supplyAsync {
            runCatching { addressClient.getByCustomerIds(ids) }.getOrDefault(emptyMap())
        }
        val accountsFuture = CompletableFuture.supplyAsync {
            runCatching { bankAccountClient.getByCustomerIds(ids) }.getOrDefault(emptyMap())
        }
        val contactsFuture = CompletableFuture.supplyAsync {
            runCatching { contactClient.getByCustomerIds(ids) }.getOrDefault(emptyMap())
        }

        // Wait for all results
        CompletableFuture.allOf(customersFuture, addressesFuture, accountsFuture, contactsFuture).join()

        val customers = customersFuture.get()
        if (customers.isEmpty()) {
            throw NotFoundException("investigate-bff.customer.not-found", "Customer not found")
        }
        val customer = customers.first()
        val addressMap = addressesFuture.get()
        val accountMap = accountsFuture.get()
        val contactMap = contactsFuture.get()
        val accounts = accountMap[customerId].orEmpty()

        log.info(
            "ActionLog.getCustomerSummary.collected addresses={} accounts={} contacts={}",
            addressMap[customerId]?.size ?: 0, accounts.size, contactMap[customerId]?.size ?: 0,
        )

        // Second wave: fetch transactions for all accounts
        val accountIds = accounts.map { it.id }
        val txnMap = if (accountIds.isNotEmpty()) {
            runCatching { transactionClient.getByAccountIds(accountIds) }.getOrDefault(emptyMap())
        } else {
            emptyMap()
        }

        val summary = summaryMapper.mapSummary(
            customer = customer,
            addresses = addressMap[customerId].orEmpty(),
            accounts = accounts,
            txnsByAccount = txnMap,
            contacts = contactMap[customerId].orEmpty(),
        )

        log.info("ActionLog.getCustomerSummary.end")
        return summary
    }
}
