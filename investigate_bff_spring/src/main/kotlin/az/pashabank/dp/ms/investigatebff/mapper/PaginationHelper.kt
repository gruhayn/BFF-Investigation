package az.pashabank.dp.ms.investigatebff.mapper

import az.pashabank.dp.ms.investigatebff.model.PageInfo
import az.pashabank.dp.ms.investigatebff.model.PageResponse
import org.springframework.stereotype.Component

@Component
class PaginationHelper {

    fun <T> toPageResponse(items: List<T>, offset: Int, limit: Int): PageResponse<T> {
        val total = items.size
        val safeOffset = offset.coerceAtMost(total)
        val end = (safeOffset + limit).coerceAtMost(total)
        val paged = items.subList(safeOffset, end)
        return PageResponse(
            items = paged,
            pageInfo = PageInfo(
                totalCount = total,
                offset = safeOffset,
                limit = limit,
                hasNextPage = end < total,
            ),
        )
    }

    fun parseOffset(value: String?): Int =
        value?.toIntOrNull()?.takeIf { it >= 0 } ?: 0

    fun parseLimit(value: String?): Int =
        value?.toIntOrNull()?.takeIf { it > 0 } ?: 10
}
