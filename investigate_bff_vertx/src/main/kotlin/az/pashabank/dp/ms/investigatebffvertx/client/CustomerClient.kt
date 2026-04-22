package az.pashabank.dp.ms.investigatebffvertx.client

import az.pashabank.dp.ms.investigatebffvertx.model.Customer
import az.pashabank.dp.ms.investigatebffvertx.model.CustomerFilter
import az.pashabank.dp.ms.investigatebffvertx.model.BankAccount
import az.pashabank.dp.ms.investigatebffvertx.model.AccountDetail
import az.pashabank.dp.ms.investigatebffvertx.model.AccountHolder
import az.pashabank.dp.ms.investigatebffvertx.model.AccountDetailFilter

class CustomerClient(private val dataStore: DataStore) {
    fun fetchCustomers(filter: CustomerFilter): List<Customer> {
        var list = dataStore.customers.toList()
        filter.id?.let { v -> list = list.filter { it.id == v } }
        filter.name?.let { v -> list = list.filter { it.name.contains(v, ignoreCase = true) } }
        filter.email?.let { v -> list = list.filter { it.email.contains(v, ignoreCase = true) } }
        filter.search?.let { v ->
            list = list.filter {
                it.name.contains(v, ignoreCase = true) || it.email.contains(v, ignoreCase = true) || it.id.contains(v, ignoreCase = true)
            }
        }
        return list
    }

    fun fetchAccountDetails(filter: AccountDetailFilter): List<AccountDetail> {
        var list = dataStore.accounts.toList()
        filter.id?.let { v -> list = list.filter { it.id == v } }
        filter.bankName?.let { v -> list = list.filter { it.bankName.contains(v, ignoreCase = true) } }
        filter.currency?.let { v -> list = list.filter { it.currency.equals(v, ignoreCase = true) } }
        filter.search?.let { v ->
            list = list.filter {
                it.accountNumber.contains(v, ignoreCase = true) || it.bankName.contains(v, ignoreCase = true) || it.id.contains(v, ignoreCase = true)
            }
        }
        return list.map {
            AccountDetail(
                id = it.id, accountNumber = it.accountNumber,
                bankName = it.bankName, balance = it.balance, currency = it.currency,
            )
        }
    }
}
