package az.pashabank.dp.ms.investigatebffvt.client

import az.pashabank.dp.ms.investigatebffvt.model.Address
import org.springframework.stereotype.Component

@Component
class AddressClient(private val dataStore: DataStore) {

    fun getByCustomerIds(ids: List<String>): Map<String, List<Address>> =
        dataStore.addresses
            .filter { it.customerId in ids }
            .groupBy { it.customerId }
}
