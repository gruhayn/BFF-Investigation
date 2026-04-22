package az.pashabank.dp.ms.investigatebffvt.mapper

import az.pashabank.dp.ms.investigatebffvt.model.Address
import az.pashabank.dp.ms.investigatebffvt.model.BankAccount
import az.pashabank.dp.ms.investigatebffvt.model.Contact
import az.pashabank.dp.ms.investigatebffvt.model.Customer
import az.pashabank.dp.ms.investigatebffvt.model.CustomerSummary
import az.pashabank.dp.ms.investigatebffvt.model.Transaction
import az.pashabank.dp.ms.investigatebffvt.model.TransactionRow
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
                rows.add(
                    TransactionRow(
                        transactionId = t.id,
                        accountNumber = acctNumById[acctId].orEmpty(),
                        amount = t.amount,
                        description = t.description,
                        date = t.date,
                        type = t.type,
                    ),
                )
            }
        }

        val recentActivity = rows.sortedByDescending { it.date }.take(5)

        return CustomerSummary(
            id = customer.id,
            name = customer.name,
            email = customer.email,
            totalBalance = totalBalance,
            accountCount = accounts.size,
            transactionCount = txnCount,
            addresses = addresses,
            contacts = contacts,
            recentActivity = recentActivity,
        )
    }
}
