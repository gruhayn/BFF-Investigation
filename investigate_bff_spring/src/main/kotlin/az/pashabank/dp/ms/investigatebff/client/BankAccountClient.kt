package az.pashabank.dp.ms.investigatebff.client

import az.pashabank.dp.ms.investigatebff.model.BankAccount
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class BankAccountClient {

    private val log = LoggerFactory.getLogger(BankAccountClient::class.java)

    fun getByCustomerIds(ids: List<String>): Map<String, List<BankAccount>> {
        log.info("ActionLog.fetchBankAccounts.start")
        return mapOf(
            "c1" to listOf(BankAccount("a1", "c1", "ACC-001", "First Bank", 15000.50, "USD")),
        )
    }
}
