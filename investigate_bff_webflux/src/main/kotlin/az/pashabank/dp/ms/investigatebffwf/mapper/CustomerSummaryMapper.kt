package az.pashabank.dp.ms.investigatebffwf.mapper

import az.pashabank.dp.ms.investigatebffwf.model.Address
import az.pashabank.dp.ms.investigatebffwf.model.BankAccount
import az.pashabank.dp.ms.investigatebffwf.model.Contact
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import az.pashabank.dp.ms.investigatebffwf.model.CustomerSummary
import az.pashabank.dp.ms.investigatebffwf.model.Transaction
import az.pashabank.dp.ms.investigatebffwf.model.TransactionRow
import org.springframework.stereotype.Component

@Component
class CustomerSummaryMapper {

    fun mapSummary(
        customer: Customer,
        addresses: List<Address>,
        accounts: List<BankAccount>,
        txnsByAccount: Map<String, List<Transaction>>,
        contacts: List<Contact>,
    ): CustomerSummary {
        val acctNumById = accounts.associate { it.id to it.accountNumber }
        val totalBalance = accounts.sumOf { it.balance }
        val rows = mutableListOf<TransactionRow>()
        var txnCount = 0
        for ((acctId, txns) in txnsByAccount) {
            txnCount += txns.size
            for (t in txns) {
                rows.add(TransactionRow(t.id, acctNumById[acctId].orEmpty(), t.amount, t.description, t.date, t.type))
            }
        }
        return CustomerSummary(
            id = customer.id, name = customer.name, email = customer.email,
            totalBalance = totalBalance, accountCount = accounts.size, transactionCount = txnCount,
            addresses = addresses, contacts = contacts,
            recentActivity = rows.sortedByDescending { it.date }.take(5),
        )
    }
}
