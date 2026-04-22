package az.pashabank.dp.ms.investigatebffvertx.model

data class PageInfo(val total: Int, val offset: Int, val limit: Int, val hasMore: Boolean)

data class PageResponse<T>(val items: List<T>, val pageInfo: PageInfo)
