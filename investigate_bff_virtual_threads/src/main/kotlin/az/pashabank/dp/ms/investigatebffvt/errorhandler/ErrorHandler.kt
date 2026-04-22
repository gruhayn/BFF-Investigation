package az.pashabank.dp.ms.investigatebffvt.errorhandler

import az.pashabank.dp.ms.investigatebffvt.exception.RestException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler

@RestControllerAdvice
class ErrorHandler : ResponseEntityExceptionHandler() {

    private val log = LoggerFactory.getLogger(ErrorHandler::class.java)

    @ExceptionHandler(RestException::class)
    fun handleRestException(ex: RestException): ResponseEntity<ErrorResponse> {
        log.error("ActionLog.handleRestException code={} message={}", ex.code, ex.message)
        return ResponseEntity(ErrorResponse(code = ex.code, message = ex.message), ex.httpStatus)
    }

    @ExceptionHandler(Exception::class)
    fun handleGenericException(ex: Exception): ResponseEntity<ErrorResponse> {
        log.error("ActionLog.handleGenericException", ex)
        return ResponseEntity(
            ErrorResponse(code = "investigate-bff-vt.internal-error", message = "Internal server error"),
            HttpStatus.INTERNAL_SERVER_ERROR,
        )
    }
}
