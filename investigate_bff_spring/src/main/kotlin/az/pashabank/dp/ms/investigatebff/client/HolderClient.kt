package az.pashabank.dp.ms.investigatebff.client

import az.pashabank.dp.ms.investigatebff.model.AccountHolder
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class HolderClient {

    private val log = LoggerFactory.getLogger(HolderClient::class.java)

    fun getByAccountIds(ids: List<String>): Map<String, AccountHolder> {
        log.info("ActionLog.fetchHolders.start")
        return mapOf(
            "a1" to AccountHolder("c1", "John Doe", "john.doe@example.com"),
        )
    }
}
