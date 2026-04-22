package az.pashabank.dp.ms.investigatebffwf.enrichment.account

import az.pashabank.dp.ms.investigatebffwf.client.TransactionClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffwf.model.AccountDetail
import org.springframework.stereotype.Component

@Component
class AccountTransactionEnricher(private val transactionClient: TransactionClient) : Enricher<AccountDetail> {
    override fun key() = "transactions"
    override fun enrich(items: List<AccountDetail>) {
        val grouped = transactionClient.getByAccountIds(items.map { it.id }).block() ?: return
        items.forEach { a -> a.transactions = grouped[a.id] }
    }
}
