package az.pashabank.dp.ms.investigatebff.client

import az.pashabank.dp.ms.investigatebff.model.Transaction
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class TransactionClient {

    private val log = LoggerFactory.getLogger(TransactionClient::class.java)

    fun getByAccountIds(ids: List<String>): Map<String, List<Transaction>> {
        log.info("ActionLog.fetchTransactions.start")
        return mapOf(
            "a1" to listOf(Transaction("t1", "a1", 500.00, "Salary deposit", "2026-03-01", "credit")),
        )
    }
}
