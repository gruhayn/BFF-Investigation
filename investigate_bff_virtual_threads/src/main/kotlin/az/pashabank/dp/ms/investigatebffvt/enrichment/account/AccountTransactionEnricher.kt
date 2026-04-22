package az.pashabank.dp.ms.investigatebffvt.enrichment.account

import az.pashabank.dp.ms.investigatebffvt.client.TransactionClient
import az.pashabank.dp.ms.investigatebffvt.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffvt.model.AccountDetail
import org.springframework.stereotype.Component

@Component
class AccountTransactionEnricher(
    private val transactionClient: TransactionClient,
) : Enricher<AccountDetail> {

    override fun key(): String = "transactions"

    override fun enrich(items: List<AccountDetail>) {
        val ids = items.map { it.id }
        val grouped = transactionClient.getByAccountIds(ids)
        items.forEach { a -> a.transactions = grouped[a.id] }
    }
}
