package az.pashabank.dp.ms.investigatebffvt.client

import az.pashabank.dp.ms.investigatebffvt.model.Contact
import org.springframework.stereotype.Component

@Component
class ContactClient(private val dataStore: DataStore) {

    fun getByCustomerIds(ids: List<String>): Map<String, List<Contact>> =
        dataStore.contacts
            .filter { it.customerId in ids }
            .groupBy { it.customerId }
}
