package az.pashabank.dp.ms.investigatebffvt.exception

import org.springframework.http.HttpStatus

open class RestException(
    val code: String,
    val httpStatus: HttpStatus,
    override val message: String,
) : RuntimeException(message)
