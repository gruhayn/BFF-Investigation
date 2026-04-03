package az.pashabank.dp.ms.investigatebff.client

import az.pashabank.dp.ms.investigatebff.model.Address
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class AddressClient {

    private val log = LoggerFactory.getLogger(AddressClient::class.java)

    fun getByCustomerIds(ids: List<String>): Map<String, List<Address>> {
        log.info("ActionLog.fetchAddresses.start")
        return mapOf(
            "c1" to listOf(Address("addr1", "c1", "123 Main St", "New York", "USA", "10001")),
        )
    }
}
