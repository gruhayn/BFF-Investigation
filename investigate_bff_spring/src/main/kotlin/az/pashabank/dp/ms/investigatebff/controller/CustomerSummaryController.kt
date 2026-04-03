package az.pashabank.dp.ms.investigatebff.controller

import az.pashabank.dp.ms.investigatebff.exception.ValidationException
import az.pashabank.dp.ms.investigatebff.model.CustomerSummary
import az.pashabank.dp.ms.investigatebff.service.CustomerSummaryService
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/customer-summary")
@Tag(name = "Customer Summary API")
class CustomerSummaryController(
    private val customerSummaryService: CustomerSummaryService,
) {

    @GetMapping
    @Operation(summary = "Get customer summary with concurrent data aggregation")
    fun getCustomerSummary(
        @RequestParam("id", required = false) id: String?,
    ): CustomerSummary {
        if (id.isNullOrBlank()) {
            throw ValidationException(
                "investigate-bff.validation.id-required",
                "id query parameter is required",
            )
        }
        return customerSummaryService.getCustomerSummary(id)
    }
}
