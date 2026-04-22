package az.pashabank.dp.ms.investigatebffwf.service

import az.pashabank.dp.ms.investigatebffwf.client.CustomerClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.EnrichmentPipeline
import az.pashabank.dp.ms.investigatebffwf.enrichment.account.AccountTransactionEnricher
import az.pashabank.dp.ms.investigatebffwf.enrichment.account.HolderEnricher
import az.pashabank.dp.ms.investigatebffwf.mapper.AccountMapper
import az.pashabank.dp.ms.investigatebffwf.mapper.PaginationHelper
import az.pashabank.dp.ms.investigatebffwf.model.AccountDetail
import az.pashabank.dp.ms.investigatebffwf.model.PageResponse
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import reactor.core.publisher.Mono

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
        filterId: String?, filterBankName: String?, filterCurrency: String?,
        search: String?, pageOffset: String?, pageLimit: String?, include: String?,
    ): Mono<PageResponse<AccountDetail>> {
        log.info("ActionLog.getAccounts.start")
        val filter = accountMapper.parseFilter(filterId, filterBankName, filterCurrency, search)
        val offset = paginationHelper.parseOffset(pageOffset)
        val limit = paginationHelper.parseLimit(pageLimit)
        val includes = parseIncludes(include)

        return customerClient.fetchAccountDetails(filter).flatMap { accounts ->
            log.info("ActionLog.getAccounts.fetched count={}", accounts.size)
            val resp = paginationHelper.toPageResponse(accounts, offset, limit)
            enrichmentPipeline.run(resp.items, enrichers, includes).thenReturn(resp)
        }
    }

    private fun parseIncludes(include: String?): Set<String> =
        include?.split(",")?.map { it.trim() }?.filter { it.isNotBlank() }?.toSet() ?: emptySet()
}
