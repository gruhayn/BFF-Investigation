package az.pashabank.dp.ms.investigatebffwf.enrichment.customer

import az.pashabank.dp.ms.investigatebffwf.client.AddressClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import org.springframework.stereotype.Component

@Component
class AddressEnricher(private val addressClient: AddressClient) : Enricher<Customer> {
    override fun key() = "addresses"
    override fun enrich(items: List<Customer>) {
        val grouped = addressClient.getByCustomerIds(items.map { it.id }).block() ?: return
        items.forEach { c -> c.addresses = grouped[c.id] }
    }
}
