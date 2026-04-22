package az.pashabank.dp.ms.investigatebffvertx.client

import az.pashabank.dp.ms.investigatebffvertx.model.Transaction

class TransactionClient(private val dataStore: DataStore) {
    fun getByAccountIds(ids: List<String>): Map<String, List<Transaction>> =
        dataStore.transactions.filter { it.accountId in ids }.groupBy { it.accountId }
}
