package az.pashabank.dp.ms.investigatebffwf.client

import az.pashabank.dp.ms.investigatebffwf.model.AccountDetail
import az.pashabank.dp.ms.investigatebffwf.model.AccountDetailFilter
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import az.pashabank.dp.ms.investigatebffwf.model.CustomerFilter
import org.springframework.stereotype.Component
import reactor.core.publisher.Mono
import reactor.core.scheduler.Schedulers

@Component
class CustomerClient(private val dataStore: DataStore) {

    fun fetchCustomers(filter: CustomerFilter): Mono<List<Customer>> =
        Mono.fromCallable {
            dataStore.customers.filter { c ->
                (filter.id == null || c.id == filter.id) &&
                (filter.name == null || c.name.contains(filter.name, ignoreCase = true)) &&
                (filter.email == null || c.email.contains(filter.email, ignoreCase = true)) &&
                (filter.search == null || c.name.contains(filter.search, ignoreCase = true) ||
                    c.email.contains(filter.search, ignoreCase = true))
            }
        }.subscribeOn(Schedulers.boundedElastic())

    fun fetchAccountDetails(filter: AccountDetailFilter): Mono<List<AccountDetail>> =
        Mono.fromCallable {
            dataStore.accounts.filter { a ->
                (filter.id == null || a.id == filter.id) &&
                (filter.bankName == null || a.bankName.contains(filter.bankName, ignoreCase = true)) &&
                (filter.currency == null || a.currency == filter.currency) &&
                (filter.search == null || a.bankName.contains(filter.search, ignoreCase = true) ||
                    a.accountNumber.contains(filter.search, ignoreCase = true))
            }.map { a -> AccountDetail(a.id, a.accountNumber, a.bankName, a.balance, a.currency) }
        }.subscribeOn(Schedulers.boundedElastic())
}
