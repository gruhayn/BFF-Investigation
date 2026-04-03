package az.pashabank.dp.ms.investigatebff.service

import az.pashabank.dp.ms.investigatebff.client.CustomerClient
import az.pashabank.dp.ms.investigatebff.enrichment.EnrichmentPipeline
import az.pashabank.dp.ms.investigatebff.enrichment.account.AccountTransactionEnricher
import az.pashabank.dp.ms.investigatebff.enrichment.account.HolderEnricher
import az.pashabank.dp.ms.investigatebff.mapper.AccountMapper
import az.pashabank.dp.ms.investigatebff.mapper.PaginationHelper
import az.pashabank.dp.ms.investigatebff.model.AccountDetail
import az.pashabank.dp.ms.investigatebff.model.PageResponse
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

@Service
class AccountService(
    private val customerClient: CustomerClient,
    private val accountMapper: AccountMapper,
    private val paginationHelper: PaginationHelper,
    private val enrichmentPipeline: EnrichmentPipeline,
    holderEnricher: HolderEnricher,
    accountTransactionEnricher: AccountTransactionEnricher,
) {

    private val log = LoggerFactory.getLogger(AccountService::class.java)
    private val enrichers = listOf(holderEnricher, accountTransactionEnricher)

    fun getAccounts(
        filterId: String?,
        filterBankName: String?,
        filterCurrency: String?,
        search: String?,
        pageOffset: String?,
        pageLimit: String?,
        include: String?,
    ): PageResponse<AccountDetail> {
        log.info("ActionLog.getAccounts.start")
        val filter = accountMapper.parseFilter(filterId, filterBankName, filterCurrency, search)
        val accounts = customerClient.fetchAccountDetails(filter)
        log.info("ActionLog.getAccounts.fetched count={}", accounts.size)

        val offset = paginationHelper.parseOffset(pageOffset)
        val limit = paginationHelper.parseLimit(pageLimit)
        val resp = paginationHelper.toPageResponse(accounts, offset, limit)

        val includes = parseIncludes(include)
        enrichmentPipeline.run(resp.items, enrichers, includes)

        log.info("ActionLog.getAccounts.end")
        return resp
    }

    private fun parseIncludes(include: String?): Set<String> =
        include?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotBlank() }
            ?.toSet()
            ?: emptySet()
}
