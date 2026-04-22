package az.pashabank.dp.ms.investigatebffvertx.service

import az.pashabank.dp.ms.investigatebffvertx.client.CustomerClient
import az.pashabank.dp.ms.investigatebffvertx.client.HolderClient
import az.pashabank.dp.ms.investigatebffvertx.client.TransactionClient
import az.pashabank.dp.ms.investigatebffvertx.model.AccountDetail
import az.pashabank.dp.ms.investigatebffvertx.model.AccountDetailFilter
import az.pashabank.dp.ms.investigatebffvertx.model.PageInfo
import az.pashabank.dp.ms.investigatebffvertx.model.PageResponse
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import org.slf4j.LoggerFactory

class AccountService(
    private val customerClient: CustomerClient,
    private val holderClient: HolderClient,
    private val transactionClient: TransactionClient,
) {
    private val log = LoggerFactory.getLogger(AccountService::class.java)

    suspend fun getAccounts(
        filterId: String?, filterBankName: String?, filterCurrency: String?,
        search: String?, offset: Int, limit: Int, includes: Set<String>,
    ): PageResponse<AccountDetail> = withContext(Dispatchers.IO) {
        log.info("ActionLog.getAccounts.start")
        val filter = AccountDetailFilter(filterId, filterBankName, filterCurrency, search)
        val accounts = customerClient.fetchAccountDetails(filter)
        val total = accounts.size
        val safeOffset = offset.coerceAtMost(total)
        val page = accounts.subList(safeOffset, (safeOffset + limit).coerceAtMost(total))

        coroutineScope {
            val holderDeferred = if ("holder" in includes) async { holderClient.getByAccountIds(page.map { it.id }) } else null
            val txnDeferred = if ("transactions" in includes) async { transactionClient.getByAccountIds(page.map { it.id }) } else null
            holderDeferred?.await()?.let { holders -> page.forEach { it.holder = holders[it.id] } }
            txnDeferred?.await()?.let { txns -> page.forEach { it.transactions = txns[it.id] } }
        }

        PageResponse(items = page, pageInfo = PageInfo(total, safeOffset, limit, (safeOffset + limit) < total))
    }
}
