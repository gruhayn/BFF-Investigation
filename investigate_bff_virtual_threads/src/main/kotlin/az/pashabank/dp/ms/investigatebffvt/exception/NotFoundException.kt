package az.pashabank.dp.ms.investigatebffvt.exception

import org.springframework.http.HttpStatus

class NotFoundException(code: String, message: String) :
    RestException(code, HttpStatus.NOT_FOUND, message)
