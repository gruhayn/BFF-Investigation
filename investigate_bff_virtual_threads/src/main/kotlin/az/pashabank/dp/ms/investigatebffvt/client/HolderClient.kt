package az.pashabank.dp.ms.investigatebffvt.client

import az.pashabank.dp.ms.investigatebffvt.model.AccountHolder
import az.pashabank.dp.ms.investigatebffvt.model.Customer
import org.springframework.stereotype.Component

@Component
class HolderClient(private val dataStore: DataStore) {

    fun getByAccountIds(ids: List<String>): Map<String, AccountHolder> {
        val accountById = dataStore.accounts.filter { it.id in ids }.associateBy { it.id }
        val customerById = dataStore.customers.associateBy { it.id }
        return accountById.mapValues { (_, acc) ->
            val cust: Customer? = customerById[acc.customerId]
            AccountHolder(
                id = acc.customerId,
                name = cust?.name ?: "Unknown",
                email = cust?.email ?: "",
            )
        }
    }
}
