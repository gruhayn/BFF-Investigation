package az.pashabank.dp.ms.investigatebffvertx.client

import az.pashabank.dp.ms.investigatebffvertx.model.AccountHolder

class HolderClient(private val dataStore: DataStore) {
    fun getByAccountIds(ids: List<String>): Map<String, AccountHolder> {
        val idSet = ids.toSet()
        return dataStore.accounts.filter { it.id in idSet }.mapNotNull { acct ->
            val customer = dataStore.customers.find { it.id == acct.customerId } ?: return@mapNotNull null
            acct.id to AccountHolder(id = customer.id, name = customer.name, email = customer.email)
        }.toMap()
    }
}
