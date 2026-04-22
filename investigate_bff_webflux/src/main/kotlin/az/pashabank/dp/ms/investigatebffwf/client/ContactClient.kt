package az.pashabank.dp.ms.investigatebffwf.client

import az.pashabank.dp.ms.investigatebffwf.model.Contact
import org.springframework.stereotype.Component
import reactor.core.publisher.Mono
import reactor.core.scheduler.Schedulers

@Component
class ContactClient(private val dataStore: DataStore) {

    fun getByCustomerIds(ids: List<String>): Mono<Map<String, List<Contact>>> =
        Mono.fromCallable {
            dataStore.contacts.filter { it.customerId in ids }.groupBy { it.customerId }
        }.subscribeOn(Schedulers.boundedElastic())
}
