package az.pashabank.dp.ms.investigatebffwf.enrichment.customer

import az.pashabank.dp.ms.investigatebffwf.client.TransactionClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import org.springframework.stereotype.Component

@Component
class TransactionEnricher(private val transactionClient: TransactionClient) : Enricher<Customer> {
    override fun key() = "transactions"
    override fun dependsOn() = "bankAccounts"
    override fun enrich(items: List<Customer>) {
        val accountIds = items.flatMap { it.bankAccounts.orEmpty() }.map { it.id }
        if (accountIds.isEmpty()) return
        val grouped = transactionClient.getByAccountIds(accountIds).block() ?: return
        items.forEach { c -> c.bankAccounts?.forEach { a -> a.transactions = grouped[a.id] } }
    }
}
