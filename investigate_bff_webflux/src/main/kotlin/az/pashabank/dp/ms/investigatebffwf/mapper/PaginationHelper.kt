package az.pashabank.dp.ms.investigatebffwf.mapper

import az.pashabank.dp.ms.investigatebffwf.model.PageInfo
import az.pashabank.dp.ms.investigatebffwf.model.PageResponse
import org.springframework.stereotype.Component

@Component
class PaginationHelper {

    fun <T> toPageResponse(items: List<T>, offset: Int, limit: Int): PageResponse<T> {
        val total = items.size
        val safeOffset = offset.coerceAtMost(total)
        val end = (safeOffset + limit).coerceAtMost(total)
        return PageResponse(
            items = items.subList(safeOffset, end),
            pageInfo = PageInfo(total, safeOffset, limit, end < total),
        )
    }

    fun parseOffset(value: String?): Int = value?.toIntOrNull()?.takeIf { it >= 0 } ?: 0
    fun parseLimit(value: String?): Int = value?.toIntOrNull()?.takeIf { it > 0 } ?: 10
}
