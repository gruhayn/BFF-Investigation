package az.pashabank.dp.ms.investigatebffwf.controller

import az.pashabank.dp.ms.investigatebffwf.model.Customer
import az.pashabank.dp.ms.investigatebffwf.model.PageResponse
import az.pashabank.dp.ms.investigatebffwf.service.CustomerService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import reactor.core.publisher.Mono

@RestController
@RequestMapping("/customers")
class CustomerController(private val customerService: CustomerService) {

    @GetMapping
    fun getCustomers(
        @RequestParam(required = false) filterId: String?,
        @RequestParam(required = false) filterName: String?,
        @RequestParam(required = false) filterEmail: String?,
        @RequestParam(required = false) search: String?,
        @RequestParam(required = false) pageOffset: String?,
        @RequestParam(required = false) pageLimit: String?,
        @RequestParam(required = false) include: String?,
    ): Mono<PageResponse<Customer>> =
        customerService.getCustomers(filterId, filterName, filterEmail, search, pageOffset, pageLimit, include)
}
