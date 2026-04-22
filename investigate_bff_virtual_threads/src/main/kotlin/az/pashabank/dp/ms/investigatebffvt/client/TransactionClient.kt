package az.pashabank.dp.ms.investigatebffvt.client

import az.pashabank.dp.ms.investigatebffvt.model.Transaction
import org.springframework.stereotype.Component

@Component
class TransactionClient(private val dataStore: DataStore) {

    fun getByAccountIds(ids: List<String>): Map<String, List<Transaction>> =
        dataStore.transactions
            .filter { it.accountId in ids }
            .groupBy { it.accountId }
}
