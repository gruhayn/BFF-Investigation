package az.pashabank.dp.ms.investigatebffvertx.client

import az.pashabank.dp.ms.investigatebffvertx.model.Address
import az.pashabank.dp.ms.investigatebffvertx.model.BankAccount
import az.pashabank.dp.ms.investigatebffvertx.model.Contact
import az.pashabank.dp.ms.investigatebffvertx.model.Customer
import az.pashabank.dp.ms.investigatebffvertx.model.Transaction
import org.slf4j.LoggerFactory

class DataStore {

    private val log = LoggerFactory.getLogger(DataStore::class.java)

    val customers: List<Customer>
    val accounts: List<BankAccount>
    val addresses: List<Address>
    val transactions: List<Transaction>
    val contacts: List<Contact>

    init {
        val baseCustomers = listOf(
            Customer(id = "c1", name = "John Doe", email = "john.doe@example.com"),
            Customer(id = "c2", name = "Jane Smith", email = "jane.smith@example.com"),
            Customer(id = "c3", name = "Bob Johnson", email = "bob.johnson@example.com"),
            Customer(id = "c4", name = "Alice Williams", email = "alice.w@example.com"),
            Customer(id = "c5", name = "Charlie Brown", email = "charlie.b@example.com"),
        )
        val baseAccounts = listOf(
            BankAccount("a1", "c1", "ACC-001", "First Bank", 15000.50, "USD"),
            BankAccount("a2", "c1", "ACC-002", "Euro Bank", 8500.00, "EUR"),
            BankAccount("a3", "c2", "ACC-003", "First Bank", 23000.00, "USD"),
            BankAccount("a4", "c3", "ACC-004", "Swiss Bank", 45000.75, "CHF"),
            BankAccount("a5", "c3", "ACC-005", "First Bank", 12000.00, "USD"),
            BankAccount("a6", "c4", "ACC-006", "Euro Bank", 6500.25, "EUR"),
            BankAccount("a7", "c5", "ACC-007", "First Bank", 31000.00, "USD"),
            BankAccount("a8", "c5", "ACC-008", "Asia Bank", 18000.00, "JPY"),
        )
        val baseAddresses = listOf(
            Address("addr1", "c1", "123 Main St", "New York", "USA", "10001"),
            Address("addr2", "c1", "456 Park Ave", "New York", "USA", "10002"),
            Address("addr3", "c2", "789 Oak Rd", "London", "UK", "SW1A 1AA"),
            Address("addr4", "c3", "321 Pine St", "Berlin", "Germany", "10115"),
            Address("addr5", "c4", "654 Elm Blvd", "Paris", "France", "75001"),
            Address("addr6", "c4", "987 Cedar Ln", "Lyon", "France", "69001"),
            Address("addr7", "c5", "111 Maple Dr", "Tokyo", "Japan", "100-0001"),
        )
        val baseTransactions = listOf(
            Transaction("t1", "a1", 500.00, "Salary deposit", "2026-03-01", "credit"),
            Transaction("t2", "a1", 120.50, "Grocery store", "2026-03-05", "debit"),
            Transaction("t3", "a1", 75.00, "Electric bill", "2026-03-10", "debit"),
            Transaction("t4", "a2", 1000.00, "Transfer in", "2026-03-02", "credit"),
            Transaction("t5", "a2", 200.00, "Online shopping", "2026-03-08", "debit"),
            Transaction("t6", "a3", 3000.00, "Salary deposit", "2026-03-01", "credit"),
            Transaction("t7", "a3", 450.00, "Restaurant", "2026-03-12", "debit"),
            Transaction("t8", "a4", 5000.00, "Investment return", "2026-03-03", "credit"),
            Transaction("t9", "a4", 800.00, "Insurance", "2026-03-07", "debit"),
            Transaction("t10", "a5", 150.00, "Subscription", "2026-03-04", "debit"),
            Transaction("t11", "a6", 2500.00, "Freelance payment", "2026-03-06", "credit"),
            Transaction("t12", "a7", 4200.00, "Salary deposit", "2026-03-01", "credit"),
            Transaction("t13", "a7", 350.00, "Gas station", "2026-03-09", "debit"),
            Transaction("t14", "a8", 1500.00, "Transfer in", "2026-03-02", "credit"),
            Transaction("t15", "a8", 600.00, "Electronics", "2026-03-11", "debit"),
        )
        val baseContacts = listOf(
            Contact("con1", "c1", "+1-555-0101", "mobile"),
            Contact("con2", "c1", "+1-555-0102", "work"),
            Contact("con3", "c2", "+44-20-1234", "home"),
            Contact("con4", "c2", "+44-20-5678", "mobile"),
            Contact("con5", "c3", "+49-30-9876", "work"),
            Contact("con6", "c4", "+33-1-4321", "mobile"),
            Contact("con7", "c5", "+81-3-5555", "home"),
            Contact("con8", "c5", "+81-3-6666", "work"),
        )

        customers = baseCustomers + multiply(baseCustomers, 100) { c, i -> c.copy(id = "${c.id}_$i", email = "${c.email}_$i") }
        accounts = baseAccounts + multiply(baseAccounts, 100) { a, i -> a.copy(id = "${a.id}_$i", customerId = "${a.customerId}_$i", accountNumber = "${a.accountNumber}_$i") }
        addresses = baseAddresses + multiply(baseAddresses, 100) { a, i -> a.copy(id = "${a.id}_$i", customerId = "${a.customerId}_$i") }
        transactions = baseTransactions + multiply(baseTransactions, 100) { t, i -> t.copy(id = "${t.id}_$i", accountId = "${t.accountId}_$i") }
        contacts = baseContacts + multiply(baseContacts, 100) { c, i -> c.copy(id = "${c.id}_$i", customerId = "${c.customerId}_$i") }

        log.info(
            "ActionLog.dataStoreInit: customers={} accounts={} addresses={} transactions={} contacts={}",
            customers.size, accounts.size, addresses.size, transactions.size, contacts.size,
        )
    }

    private fun <T> multiply(src: List<T>, times: Int, mutate: (T, Int) -> T): List<T> =
        (1..times).flatMap { i -> src.map { mutate(it, i) } }
}
