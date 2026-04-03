package az.pashabank.dp.ms.investigatebff.service

import az.pashabank.dp.ms.investigatebff.client.CustomerClient
import az.pashabank.dp.ms.investigatebff.enrichment.EnrichmentPipeline
import az.pashabank.dp.ms.investigatebff.enrichment.customer.AddressEnricher
import az.pashabank.dp.ms.investigatebff.enrichment.customer.BankAccountEnricher
import az.pashabank.dp.ms.investigatebff.enrichment.customer.ContactEnricher
import az.pashabank.dp.ms.investigatebff.enrichment.customer.TransactionEnricher
import az.pashabank.dp.ms.investigatebff.mapper.CustomerMapper
import az.pashabank.dp.ms.investigatebff.mapper.PaginationHelper
import az.pashabank.dp.ms.investigatebff.model.Customer
import az.pashabank.dp.ms.investigatebff.model.PageResponse
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

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
        filterId: String?,
        filterName: String?,
        filterEmail: String?,
        search: String?,
        pageOffset: String?,
        pageLimit: String?,
        include: String?,
    ): PageResponse<Customer> {
        log.info("ActionLog.getCustomers.start")
        val filter = customerMapper.parseFilter(filterId, filterName, filterEmail, search)
        val customers = customerClient.fetchCustomers(filter)
        log.info("ActionLog.getCustomers.fetched count={}", customers.size)

        val offset = paginationHelper.parseOffset(pageOffset)
        val limit = paginationHelper.parseLimit(pageLimit)
        val resp = paginationHelper.toPageResponse(customers, offset, limit)

        val includes = parseIncludes(include)
        enrichmentPipeline.run(resp.items, enrichers, includes)

        log.info("ActionLog.getCustomers.end")
        return resp
    }

    private fun parseIncludes(include: String?): Set<String> =
        include?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotBlank() }
            ?.toSet()
            ?: emptySet()
}
