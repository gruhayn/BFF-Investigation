package az.pashabank.dp.ms.investigatebffvt.enrichment.customer

import az.pashabank.dp.ms.investigatebffvt.client.BankAccountClient
import az.pashabank.dp.ms.investigatebffvt.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffvt.model.Customer
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
