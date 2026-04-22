package az.pashabank.dp.ms.investigatebffwf.enrichment.customer

import az.pashabank.dp.ms.investigatebffwf.client.ContactClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import org.springframework.stereotype.Component

@Component
class ContactEnricher(private val contactClient: ContactClient) : Enricher<Customer> {
    override fun key() = "contacts"
    override fun enrich(items: List<Customer>) {
        val grouped = contactClient.getByCustomerIds(items.map { it.id }).block() ?: return
        items.forEach { c -> c.contacts = grouped[c.id] }
    }
}
