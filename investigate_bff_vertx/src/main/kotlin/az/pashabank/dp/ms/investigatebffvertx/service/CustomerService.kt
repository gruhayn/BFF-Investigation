package az.pashabank.dp.ms.investigatebffvertx.service

import az.pashabank.dp.ms.investigatebffvertx.client.AddressClient
import az.pashabank.dp.ms.investigatebffvertx.client.BankAccountClient
import az.pashabank.dp.ms.investigatebffvertx.client.ContactClient
import az.pashabank.dp.ms.investigatebffvertx.client.CustomerClient
import az.pashabank.dp.ms.investigatebffvertx.client.TransactionClient
import az.pashabank.dp.ms.investigatebffvertx.model.Customer
import az.pashabank.dp.ms.investigatebffvertx.model.CustomerFilter
import az.pashabank.dp.ms.investigatebffvertx.model.PageInfo
import az.pashabank.dp.ms.investigatebffvertx.model.PageResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import org.slf4j.LoggerFactory

class CustomerService(
    private val customerClient: CustomerClient,
    private val addressClient: AddressClient,
    private val bankAccountClient: BankAccountClient,
    private val contactClient: ContactClient,
    private val transactionClient: TransactionClient,
) {
    private val log = LoggerFactory.getLogger(CustomerService::class.java)

    suspend fun getCustomers(
        filterId: String?, filterName: String?, filterEmail: String?,
        search: String?, offset: Int, limit: Int, includes: Set<String>,
    ): PageResponse<Customer> = withContext(Dispatchers.IO) {
        log.info("ActionLog.getCustomers.start")
        val filter = CustomerFilter(filterId, filterName, filterEmail, search)
        val customers = customerClient.fetchCustomers(filter)
        val total = customers.size
        val safeOffset = offset.coerceAtMost(total)
        val page = customers.subList(safeOffset, (safeOffset + limit).coerceAtMost(total))
        val ids = page.map { it.id }

        coroutineScope {
            val addrDeferred = if ("addresses" in includes) async { addressClient.getByCustomerIds(ids) } else null
            val acctDeferred = if ("bankAccounts" in includes) async { bankAccountClient.getByCustomerIds(ids) } else null
            val contactDeferred = if ("contacts" in includes) async { contactClient.getByCustomerIds(ids) } else null

            addrDeferred?.await()?.let { map -> page.forEach { it.addresses = map[it.id] } }
            val acctMap = acctDeferred?.await()
            acctMap?.let { map -> page.forEach { it.bankAccounts = map[it.id] } }
            contactDeferred?.await()?.let { map -> page.forEach { it.contacts = map[it.id] } }

            // transactions depend on bankAccounts
            if ("transactions" in includes && acctMap != null) {
                val allAccountIds = page.flatMap { it.bankAccounts.orEmpty() }.map { it.id }
                if (allAccountIds.isNotEmpty()) {
                    val txnMap = transactionClient.getByAccountIds(allAccountIds)
                    page.forEach { c -> c.bankAccounts?.forEach { a -> a.transactions = txnMap[a.id] } }
                }
            }
        }

        PageResponse(items = page, pageInfo = PageInfo(total, safeOffset, limit, (safeOffset + limit) < total))
    }
}
