package az.pashabank.dp.ms.investigatebffvt.enrichment.customer

import az.pashabank.dp.ms.investigatebffvt.client.ContactClient
import az.pashabank.dp.ms.investigatebffvt.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffvt.model.Customer
import org.springframework.stereotype.Component

@Component
class ContactEnricher(
    private val contactClient: ContactClient,
) : Enricher<Customer> {

    override fun key(): String = "contacts"

    override fun enrich(items: List<Customer>) {
        val ids = items.map { it.id }
        val grouped = contactClient.getByCustomerIds(ids)
        items.forEach { c -> c.contacts = grouped[c.id] }
    }
}
