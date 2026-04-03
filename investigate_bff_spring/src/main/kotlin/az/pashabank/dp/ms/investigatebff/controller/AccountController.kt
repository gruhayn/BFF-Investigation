package az.pashabank.dp.ms.investigatebff.controller

import az.pashabank.dp.ms.investigatebff.model.AccountDetail
import az.pashabank.dp.ms.investigatebff.model.PageResponse
import az.pashabank.dp.ms.investigatebff.service.AccountService
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/accounts")
@Tag(name = "Account API")
class AccountController(
    private val accountService: AccountService,
) {

    @GetMapping
    @Operation(summary = "Get accounts with optional filtering, pagination, and includes")
    fun getAccounts(
        @RequestParam("filter.id", required = false) filterId: String?,
        @RequestParam("filter.bankName", required = false) filterBankName: String?,
        @RequestParam("filter.currency", required = false) filterCurrency: String?,
        @RequestParam("search", required = false) search: String?,
        @RequestParam("page.offset", required = false) pageOffset: String?,
        @RequestParam("page.limit", required = false) pageLimit: String?,
        @RequestParam("include", required = false) include: String?,
    ): PageResponse<AccountDetail> =
        accountService.getAccounts(filterId, filterBankName, filterCurrency, search, pageOffset, pageLimit, include)
}
