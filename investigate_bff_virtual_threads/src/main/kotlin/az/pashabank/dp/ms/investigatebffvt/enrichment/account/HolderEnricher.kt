package az.pashabank.dp.ms.investigatebffvt.enrichment.account

import az.pashabank.dp.ms.investigatebffvt.client.HolderClient
import az.pashabank.dp.ms.investigatebffvt.enrichment.Enricher
import az.pashabank.dp.ms.investigatebffvt.model.AccountDetail
import org.springframework.stereotype.Component

@Component
class HolderEnricher(
    private val holderClient: HolderClient,
) : Enricher<AccountDetail> {

    override fun key(): String = "holder"

    override fun enrich(items: List<AccountDetail>) {
        val ids = items.map { it.id }
        val holders = holderClient.getByAccountIds(ids)
        items.forEach { a -> a.holder = holders[a.id] }
    }
}
