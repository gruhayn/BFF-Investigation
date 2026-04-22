package az.pashabank.dp.ms.investigatebffvertx.client

import az.pashabank.dp.ms.investigatebffvertx.model.BankAccount

class BankAccountClient(private val dataStore: DataStore) {
    fun getByCustomerIds(ids: List<String>): Map<String, List<BankAccount>> =
        dataStore.accounts.filter { it.customerId in ids }.groupBy { it.customerId }
}
