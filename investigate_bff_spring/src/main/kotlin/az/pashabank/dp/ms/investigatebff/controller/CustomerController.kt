package az.pashabank.dp.ms.investigatebff.controller

import az.pashabank.dp.ms.investigatebff.model.Customer
import az.pashabank.dp.ms.investigatebff.model.PageResponse
import az.pashabank.dp.ms.investigatebff.service.CustomerService
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/customers")
@Tag(name = "Customer API")
class CustomerController(
    private val customerService: CustomerService,
) {

    @GetMapping
    @Operation(summary = "Get customers with optional filtering, pagination, and includes")
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
