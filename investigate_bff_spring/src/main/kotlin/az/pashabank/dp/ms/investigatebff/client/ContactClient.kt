package az.pashabank.dp.ms.investigatebff.client

import az.pashabank.dp.ms.investigatebff.model.Contact
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class ContactClient {

    private val log = LoggerFactory.getLogger(ContactClient::class.java)

    fun getByCustomerIds(ids: List<String>): Map<String, List<Contact>> {
        log.info("ActionLog.fetchContacts.start")
        return mapOf(
            "c1" to listOf(Contact("con1", "c1", "+1-555-0101", "mobile")),
        )
    }
}
