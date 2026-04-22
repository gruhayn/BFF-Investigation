package az.pashabank.dp.ms.investigatebffwf.exception

data class ValidationException(val code: String, override val message: String) : RuntimeException(message)
