package az.pashabank.dp.ms.investigatebffvt.exception

import org.springframework.http.HttpStatus

class ValidationException(code: String, message: String) :
    RestException(code, HttpStatus.BAD_REQUEST, message)
