package az.pashabank.dp.ms.investigatebffvertx.client

import az.pashabank.dp.ms.investigatebffvertx.model.Contact

class ContactClient(private val dataStore: DataStore) {
    fun getByCustomerIds(ids: List<String>): Map<String, List<Contact>> =
        dataStore.contacts.filter { it.customerId in ids }.groupBy { it.customerId }
}
