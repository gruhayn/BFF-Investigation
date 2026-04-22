package az.pashabank.dp.ms.investigatebffwf.enrichment.customer

import az.pashabank.dp.ms.investigatebffwf.client.BankAccountClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import org.springframework.stereotype.Component

@Component
class BankAccountEnricher(private val bankAccountClient: BankAccountClient) : Enricher<Customer> {
    override fun key() = "bankAccounts"
    override fun enrich(items: List<Customer>) {
        val grouped = bankAccountClient.getByCustomerIds(items.map { it.id }).block() ?: return
        items.forEach { c -> c.bankAccounts = grouped[c.id] }
    }
}
