package az.pashabank.dp.ms.investigatebffwf.client

import az.pashabank.dp.ms.investigatebffwf.model.AccountHolder
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import org.springframework.stereotype.Component
import reactor.core.publisher.Mono
import reactor.core.scheduler.Schedulers

@Component
class HolderClient(private val dataStore: DataStore) {

    fun getByAccountIds(ids: List<String>): Mono<Map<String, AccountHolder>> =
        Mono.fromCallable {
            val accountById = dataStore.accounts.filter { it.id in ids }.associateBy { it.id }
            val customerById = dataStore.customers.associateBy { it.id }
            accountById.mapValues { (_, acc) ->
                val cust: Customer? = customerById[acc.customerId]
                AccountHolder(
                    id = acc.customerId,
                    name = cust?.name ?: "Unknown",
                    email = cust?.email ?: "",
                )
            }
        }.subscribeOn(Schedulers.boundedElastic())
}
