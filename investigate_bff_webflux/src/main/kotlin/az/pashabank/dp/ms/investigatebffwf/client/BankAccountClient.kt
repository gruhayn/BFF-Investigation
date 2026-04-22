package az.pashabank.dp.ms.investigatebffwf.client

import az.pashabank.dp.ms.investigatebffwf.model.BankAccount
import org.springframework.stereotype.Component
import reactor.core.publisher.Mono
import reactor.core.scheduler.Schedulers

@Component
class BankAccountClient(private val dataStore: DataStore) {

    fun getByCustomerIds(ids: List<String>): Mono<Map<String, List<BankAccount>>> =
        Mono.fromCallable {
            dataStore.accounts.filter { it.customerId in ids }.groupBy { it.customerId }
        }.subscribeOn(Schedulers.boundedElastic())
}
