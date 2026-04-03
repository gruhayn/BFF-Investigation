package az.pashabank.dp.ms.investigatebff.enrichment.customer

import az.pashabank.dp.ms.investigatebff.client.TransactionClient
import az.pashabank.dp.ms.investigatebff.enrichment.Enricher
import az.pashabank.dp.ms.investigatebff.model.Customer
import org.springframework.stereotype.Component

@Component
class TransactionEnricher(
    private val transactionClient: TransactionClient,
) : Enricher<Customer> {

    override fun key(): String = "transactions"

    override fun dependsOn(): String = "bankAccounts"

    override fun enrich(items: List<Customer>) {
        val accountIds = items.flatMap { it.bankAccounts.orEmpty() }.map { it.id }
        if (accountIds.isEmpty()) return
        val grouped = transactionClient.getByAccountIds(accountIds)
        items.forEach { c ->
            c.bankAccounts?.forEach { a ->
                a.transactions = grouped[a.id]
            }
        }
    }
}
