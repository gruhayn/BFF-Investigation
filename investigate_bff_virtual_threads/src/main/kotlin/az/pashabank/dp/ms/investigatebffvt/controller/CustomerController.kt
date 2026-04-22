package az.pashabank.dp.ms.investigatebffvt.controller

import az.pashabank.dp.ms.investigatebffvt.model.Customer
import az.pashabank.dp.ms.investigatebffvt.model.PageResponse
import az.pashabank.dp.ms.investigatebffvt.service.CustomerService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/customers")
class CustomerController(private val customerService: CustomerService) {

    @GetMapping
    fun getCustomers(
        @RequestParam("filter.id", required = false) filterId: String?,
        @RequestParam("filter.name", required = false) filterName: String?,
        @RequestParam("filter.email", required = false) filterEmail: String?,
        @RequestParam("search", required = false) search: String?,
        @RequestParam("page.offset", required = false) pageOffset: String?,
        @RequestParam("page.limit", required = false) pageLimit: String?,
        @RequestParam("include", required = false) include: String?,
    ): PageResponse<Customer> =
        customerService.getCustomers(filterId, filterName, filterEmail, search, pageOffset, pageLimit, include)
}
