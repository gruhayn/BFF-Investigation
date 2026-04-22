package az.pashabank.dp.ms.investigatebffwf.service

import az.pashabank.dp.ms.investigatebffwf.client.CustomerClient
import az.pashabank.dp.ms.investigatebffwf.enrichment.EnrichmentPipeline
import az.pashabank.dp.ms.investigatebffwf.enrichment.customer.AddressEnricher
import az.pashabank.dp.ms.investigatebffwf.enrichment.customer.BankAccountEnricher
import az.pashabank.dp.ms.investigatebffwf.enrichment.customer.ContactEnricher
import az.pashabank.dp.ms.investigatebffwf.enrichment.customer.TransactionEnricher
import az.pashabank.dp.ms.investigatebffwf.mapper.CustomerMapper
import az.pashabank.dp.ms.investigatebffwf.mapper.PaginationHelper
import az.pashabank.dp.ms.investigatebffwf.model.Customer
import az.pashabank.dp.ms.investigatebffwf.model.PageResponse
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import reactor.core.publisher.Mono

@Service
class CustomerService(
    private val customerClient: CustomerClient,
    private val customerMapper: CustomerMapper,
    private val paginationHelper: PaginationHelper,
    private val enrichmentPipeline: EnrichmentPipeline,
    addressEnricher: AddressEnricher,
    bankAccountEnricher: BankAccountEnricher,
    transactionEnricher: TransactionEnricher,
    contactEnricher: ContactEnricher,
) {
    private val log = LoggerFactory.getLogger(CustomerService::class.java)
    private val enrichers = listOf(addressEnricher, bankAccountEnricher, transactionEnricher, contactEnricher)

    fun getCustomers(
        filterId: String?, filterName: String?, filterEmail: String?,
        search: String?, pageOffset: String?, pageLimit: String?, include: String?,
    ): Mono<PageResponse<Customer>> {
        log.info("ActionLog.getCustomers.start")
        val filter = customerMapper.parseFilter(filterId, filterName, filterEmail, search)
        val offset = paginationHelper.parseOffset(pageOffset)
        val limit = paginationHelper.parseLimit(pageLimit)
        val includes = parseIncludes(include)

        return customerClient.fetchCustomers(filter).flatMap { customers ->
            log.info("ActionLog.getCustomers.fetched count={}", customers.size)
            val resp = paginationHelper.toPageResponse(customers, offset, limit)
            enrichmentPipeline.run(resp.items, enrichers, includes).thenReturn(resp)
        }
    }

    private fun parseIncludes(include: String?): Set<String> =
        include?.split(",")?.map { it.trim() }?.filter { it.isNotBlank() }?.toSet() ?: emptySet()
}
