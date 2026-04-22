package az.pashabank.dp.ms.investigatebffvt.enrichment.customer

import az.pashabank.dp.ms.investigatebffvt.client.AddressClient
import az.pashabank.dp.ms.investigatebffvt.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffvt.model.Customer
import org.springframework.stereotype.Component

@Component
class AddressEnricher(
    private val addressClient: AddressClient,
) : Enricher<Customer> {

    override fun key(): String = "addresses"

    override fun enrich(items: List<Customer>) {
        val ids = items.map { it.id }
        val grouped = addressClient.getByCustomerIds(ids)
        items.forEach { c -> c.addresses = grouped[c.id] }
    }
}
