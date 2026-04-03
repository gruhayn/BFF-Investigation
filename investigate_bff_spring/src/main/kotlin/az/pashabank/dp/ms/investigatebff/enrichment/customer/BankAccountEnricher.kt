package az.pashabank.dp.ms.investigatebff.enrichment.customer

import az.pashabank.dp.ms.investigatebff.client.BankAccountClient
import az.pashabank.dp.ms.investigatebff.enrichment.Enricher
import az.pashabank.dp.ms.investigatebff.model.Customer
import org.springframework.stereotype.Component

@Component
class BankAccountEnricher(
    private val bankAccountClient: BankAccountClient,
) : Enricher<Customer> {

    override fun key(): String = "bankAccounts"

    override fun enrich(items: List<Customer>) {
        val ids = items.map { it.id }
        val grouped = bankAccountClient.getByCustomerIds(ids)
        items.forEach { c -> c.bankAccounts = grouped[c.id] }
    }
}
