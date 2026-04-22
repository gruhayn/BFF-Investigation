package az.pashabank.dp.ms.investigatebffwf.enrichment.account

import az.pashabank.dp.ms.investigatebffwf.client.HolderClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffwf.model.AccountDetail
import org.springframework.stereotype.Component

@Component
class HolderEnricher(private val holderClient: HolderClient) : Enricher<AccountDetail> {
    override fun key() = "holder"
    override fun enrich(items: List<AccountDetail>) {
        val holders = holderClient.getByAccountIds(items.map { it.id }).block() ?: return
        items.forEach { a -> a.holder = holders[a.id] }
    }
}
