package az.pashabank.dp.ms.investigatebff.client

import az.pashabank.dp.ms.investigatebff.model.AccountDetail
import az.pashabank.dp.ms.investigatebff.model.AccountDetailFilter
import az.pashabank.dp.ms.investigatebff.model.Customer
import az.pashabank.dp.ms.investigatebff.model.CustomerFilter
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component

@Component
class CustomerClient {

    private val log = LoggerFactory.getLogger(CustomerClient::class.java)

    fun fetchCustomers(filter: CustomerFilter): List<Customer> {
        log.info("ActionLog.fetchCustomers.start")
        return listOf(
            Customer(id = "c1", name = "John Doe", email = "john.doe@example.com"),
        )
    }

    fun fetchAccountDetails(filter: AccountDetailFilter): List<AccountDetail> {
        log.info("ActionLog.fetchAccountDetails.start")
        return listOf(
            AccountDetail(id = "a1", accountNumber = "ACC-001", bankName = "First Bank", balance = 15000.50, currency = "USD"),
        )
    }
}
