package az.pashabank.dp.ms.investigatebffvertx.service

import az.pashabank.dp.ms.investigatebffvertx.client.AddressClient
import az.pashabank.dp.ms.investigatebffvertx.client.BankAccountClient
import az.pashabank.dp.ms.investigatebffvertx.client.ContactClient
import az.pashabank.dp.ms.investigatebffvertx.client.CustomerClient
import az.pashabank.dp.ms.investigatebffvertx.client.TransactionClient
import az.pashabank.dp.ms.investigatebffvertx.model.Address
import az.pashabank.dp.ms.investigatebffvertx.model.BankAccount
import az.pashabank.dp.ms.investigatebffvertx.model.Contact
import az.pashabank.dp.ms.investigatebffvertx.model.Customer
import az.pashabank.dp.ms.investigatebffvertx.model.CustomerFilter
import az.pashabank.dp.ms.investigatebffvertx.model.CustomerSummary
import az.pashabank.dp.ms.investigatebffvertx.model.TransactionRow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import org.slf4j.LoggerFactory

class CustomerSummaryService(
    private val customerClient: CustomerClient,
    private val addressClient: AddressClient,
    private val bankAccountClient: BankAccountClient,
    private val contactClient: ContactClient,
    private val transactionClient: TransactionClient,
) {
    private val log = LoggerFactory.getLogger(CustomerSummaryService::class.java)

    suspend fun getCustomerSummary(customerId: String): CustomerSummary = withContext(Dispatchers.IO) {
        log.info("ActionLog.getCustomerSummary.start customerId={}", customerId)
        val ids = listOf(customerId)

        // Fire 4 calls concurrently
        val customers: List<Customer>
        val addressMap: Map<String, List<Address>>
        val accountMap: Map<String, List<BankAccount>>
        val contactMap: Map<String, List<Contact>>
        coroutineScope {
            val cusD = async { customerClient.fetchCustomers(CustomerFilter(id = customerId)) }
            val adrD = async { addressClient.getByCustomerIds(ids) }
            val acctD = async { bankAccountClient.getByCustomerIds(ids) }
            val conD = async { contactClient.getByCustomerIds(ids) }
            customers = cusD.await()
            addressMap = adrD.await()
            accountMap = acctD.await()
            contactMap = conD.await()
        }

        val customer = customers.firstOrNull() ?: throw IllegalArgumentException("Customer not found: $customerId")
        val accounts = accountMap[customerId] ?: emptyList()
        val addresses = addressMap[customerId] ?: emptyList()
        val contacts = contactMap[customerId] ?: emptyList()

        // Second wave: fetch transactions
        val accountIds = accounts.map { it.id }
        val txnMap = if (accountIds.isNotEmpty()) transactionClient.getByAccountIds(accountIds) else emptyMap()

        val acctNumById = accounts.associate { it.id to it.accountNumber }
        val totalBalance = accounts.sumOf { it.balance }
        var txnCount = 0
        val rows = mutableListOf<TransactionRow>()
        for ((acctId, txns) in txnMap) {
            txnCount += txns.size
            txns.forEach { t ->
                rows.add(TransactionRow(t.id, acctNumById[acctId].orEmpty(), t.amount, t.description, t.date, t.type))
            }
        }

        log.info("ActionLog.getCustomerSummary.end")
        CustomerSummary(
            id = customer.id, name = customer.name, email = customer.email,
            totalBalance = totalBalance, accountCount = accounts.size, transactionCount = txnCount,
            addresses = addresses, contacts = contacts,
            recentActivity = rows.sortedByDescending { it.date }.take(5),
        )
    }
}
