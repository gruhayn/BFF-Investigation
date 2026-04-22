package az.pashabank.dp.ms.investigatebffwf.client

import az.pashabank.dp.ms.investigatebffwf.model.Address
import org.springframework.stereotype.Component
import reactor.core.publisher.Mono
import reactor.core.scheduler.Schedulers

@Component
class AddressClient(private val dataStore: DataStore) {

    fun getByCustomerIds(ids: List<String>): Mono<Map<String, List<Address>>> =
        Mono.fromCallable {
            dataStore.addresses.filter { it.customerId in ids }.groupBy { it.customerId }
        }.subscribeOn(Schedulers.boundedElastic())
}
