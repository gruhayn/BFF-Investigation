package az.pashabank.dp.ms.investigatebff.mapper

import az.pashabank.dp.ms.investigatebff.model.AccountDetailFilter
import org.springframework.stereotype.Component

@Component
class AccountMapper {

    fun parseFilter(
        id: String?,
        bankName: String?,
        currency: String?,
        search: String?,
    ): AccountDetailFilter = AccountDetailFilter(
        id = id?.takeIf { it.isNotBlank() },
        bankName = bankName?.takeIf { it.isNotBlank() },
        currency = currency?.takeIf { it.isNotBlank() },
        search = search?.takeIf { it.isNotBlank() },
    )
}
