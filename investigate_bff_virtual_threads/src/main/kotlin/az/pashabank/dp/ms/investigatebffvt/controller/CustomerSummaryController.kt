package az.pashabank.dp.ms.investigatebffvt.controller

import az.pashabank.dp.ms.investigatebffvt.exception.ValidationException
import az.pashabank.dp.ms.investigatebffvt.model.CustomerSummary
import az.pashabank.dp.ms.investigatebffvt.service.CustomerSummaryService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/customer-summary")
class CustomerSummaryController(private val customerSummaryService: CustomerSummaryService) {

    @GetMapping
    fun getCustomerSummary(
        @RequestParam("id", required = false) id: String?,
    ): CustomerSummary {
        if (id.isNullOrBlank()) {
            throw ValidationException(
                "investigate-bff-vt.validation.id-required",
                "id query parameter is required",
            )
        }
        return customerSummaryService.getCustomerSummary(id)
    }
}
