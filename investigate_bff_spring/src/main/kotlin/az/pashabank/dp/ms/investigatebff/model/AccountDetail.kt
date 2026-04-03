package az.pashabank.dp.ms.investigatebff.model

import com.fasterxml.jackson.annotation.JsonInclude

@JsonInclude(JsonInclude.Include.NON_NULL)
data class AccountDetail(
    val id: String,
    val accountNumber: String,
    val bankName: String,
    val balance: Double,
    val currency: String,
    var holder: AccountHolder? = null,
    var transactions: List<Transaction>? = null,
)

data class AccountHolder(
    val id: String,
    val name: String,
    val email: String,
)

data class AccountDetailFilter(
    val id: String? = null,
    val bankName: String? = null,
    val currency: String? = null,
    val search: String? = null,
)
