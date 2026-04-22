package az.pashabank.dp.ms.investigatebffvt.model

data class CustomerSummary(
    val id: String,
    val name: String,
    val email: String,
    val totalBalance: Double,
    val accountCount: Int,
    val transactionCount: Int,
    val addresses: List<Address>,
    val contacts: List<Contact>,
    val recentActivity: List<TransactionRow>,
)

data class TransactionRow(
    val transactionId: String,
    val accountNumber: String,
    val amount: Double,
    val description: String,
    val date: String,
    val type: String,
)
