package az.pashabank.dp.ms.investigatebffwf.controller

import az.pashabank.dp.ms.investigatebffwf.model.AccountDetail
import az.pashabank.dp.ms.investigatebffwf.model.PageResponse
import az.pashabank.dp.ms.investigatebffwf.service.AccountService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import reactor.core.publisher.Mono

@RestController
@RequestMapping("/accounts")
class AccountController(private val accountService: AccountService) {

    @GetMapping
    fun getAccounts(
        @RequestParam(required = false) filterId: String?,
        @RequestParam(required = false) filterBankName: String?,
        @RequestParam(required = false) filterCurrency: String?,
        @RequestParam(required = false) search: String?,
        @RequestParam(required = false) pageOffset: String?,
        @RequestParam(required = false) pageLimit: String?,
        @RequestParam(required = false) include: String?,
    ): Mono<PageResponse<AccountDetail>> =
        accountService.getAccounts(filterId, filterBankName, filterCurrency, search, pageOffset, pageLimit, include)
}
