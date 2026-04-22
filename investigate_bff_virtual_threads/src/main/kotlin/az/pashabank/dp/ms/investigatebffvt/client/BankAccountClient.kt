package az.pashabank.dp.ms.investigatebffvt.client

import az.pashabank.dp.ms.investigatebffvt.model.BankAccount
import org.springframework.stereotype.Component

@Component
class BankAccountClient(private val dataStore: DataStore) {

    fun getByCustomerIds(ids: List<String>): Map<String, List<BankAccount>> =
        dataStore.accounts
            .filter { it.customerId in ids }
            .groupBy { it.customerId }
}
