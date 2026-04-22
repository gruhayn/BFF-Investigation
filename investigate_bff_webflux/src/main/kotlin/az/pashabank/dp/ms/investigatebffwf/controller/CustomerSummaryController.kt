package az.pashabank.dp.ms.investigatebffwf.controller

import az.pashabank.dp.ms.investigatebffwf.exception.ValidationException
import az.pashabank.dp.ms.investigatebffwf.model.CustomerSummary
import az.pashabank.dp.ms.investigatebffwf.service.CustomerSummaryService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import reactor.core.publisher.Mono

@RestController
@RequestMapping("/customer-summary")
class CustomerSummaryController(private val customerSummaryService: CustomerSummaryService) {

    @GetMapping
    fun getCustomerSummary(
        @RequestParam("id", required = false) id: String?,
    ): Mono<CustomerSummary> {
        if (id.isNullOrBlank()) {
            throw ValidationException(
                "investigate-bff-wf.validation.id-required",
                "id query parameter is required",
            )
        }
        return customerSummaryService.getCustomerSummary(id)
    }
}
