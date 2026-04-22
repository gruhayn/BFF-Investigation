package az.pashabank.dp.ms.investigatebffvertx.client

import az.pashabank.dp.ms.investigatebffvertx.model.Address

class AddressClient(private val dataStore: DataStore) {
    fun getByCustomerIds(ids: List<String>): Map<String, List<Address>> =
        dataStore.addresses.filter { it.customerId in ids }.groupBy { it.customerId }
}
