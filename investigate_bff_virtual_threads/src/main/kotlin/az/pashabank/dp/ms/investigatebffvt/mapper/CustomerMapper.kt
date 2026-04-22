package az.pashabank.dp.ms.investigatebffvt.mapper

import az.pashabank.dp.ms.investigatebffvt.model.CustomerFilter
import org.springframework.stereotype.Component

@Component
class CustomerMapper {

    fun parseFilter(
        id: String?,
        name: String?,
        email: String?,
        search: String?,
    ): CustomerFilter = CustomerFilter(
        id = id?.takeIf { it.isNotBlank() },
        name = name?.takeIf { it.isNotBlank() },
        email = email?.takeIf { it.isNotBlank() },
        search = search?.takeIf { it.isNotBlank() },
    )
}
