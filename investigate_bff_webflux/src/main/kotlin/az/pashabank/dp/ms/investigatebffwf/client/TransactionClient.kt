package az.pashabank.dp.ms.investigatebffwf.client

import az.pashabank.dp.ms.investigatebffwf.model.Transaction
import org.springframework.stereotype.Component
import reactor.core.publisher.Mono
import reactor.core.scheduler.Schedulers

@Component
class TransactionClient(private val dataStore: DataStore) {

    fun getByAccountIds(ids: List<String>): Mono<Map<String, List<Transaction>>> =
        Mono.fromCallable {
            dataStore.transactions.filter { it.accountId in ids }.groupBy { it.accountId }
        }.subscribeOn(Schedulers.boundedElastic())
}
