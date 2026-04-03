package az.pashabank.dp.ms.investigatebff.errorhandler

import az.pashabank.dp.ms.investigatebff.exception.RestException
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
        val body = ErrorResponse(code = ex.code, message = ex.message)
        return ResponseEntity(body, ex.httpStatus)
    }

    @ExceptionHandler(Exception::class)
    fun handleGenericException(ex: Exception): ResponseEntity<ErrorResponse> {
        log.error("ActionLog.handleGenericException", ex)
        val body = ErrorResponse(
            code = "investigate-bff.internal-error",
            message = "Internal server error",
        )
        return ResponseEntity(body, HttpStatus.INTERNAL_SERVER_ERROR)
    }
}
