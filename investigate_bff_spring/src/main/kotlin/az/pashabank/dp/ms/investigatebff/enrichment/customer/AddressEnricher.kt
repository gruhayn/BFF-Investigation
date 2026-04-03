package az.pashabank.dp.ms.investigatebff.enrichment.customer

import az.pashabank.dp.ms.investigatebff.client.AddressClient
import az.pashabank.dp.ms.investigatebff.enrichment.Enricher
import az.pashabank.dp.ms.investigatebff.model.Customer
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
