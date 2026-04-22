package az.pashabank.dp.ms.investigatebffvt.model

import com.fasterxml.jackson.annotation.JsonInclude

@JsonInclude(JsonInclude.Include.NON_NULL)
data class Customer(
    val id: String,
    val name: String,
    val email: String,
    var addresses: List<Address>? = null,
    var bankAccounts: List<BankAccount>? = null,
    var contacts: List<Contact>? = null,
)

data class Address(
    val id: String,
    val customerId: String,
    val street: String,
    val city: String,
    val country: String,
    val zipCode: String,
)

data class BankAccount(
    val id: String,
    val customerId: String,
    val accountNumber: String,
    val bankName: String,
    val balance: Double,
    val currency: String,
    var transactions: List<Transaction>? = null,
)

data class Transaction(
    val id: String,
    val accountId: String,
    val amount: Double,
    val description: String,
    val date: String,
    val type: String,
)

data class Contact(
    val id: String,
    val customerId: String,
    val phone: String,
    val type: String,
)

data class CustomerFilter(
    val id: String? = null,
    val name: String? = null,
    val email: String? = null,
    val search: String? = null,
)
