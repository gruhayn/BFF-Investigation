package az.pashabank.dp.ms.investigatebffwf.exception

data class NotFoundException(val code: String, override val message: String) : RuntimeException(message)
