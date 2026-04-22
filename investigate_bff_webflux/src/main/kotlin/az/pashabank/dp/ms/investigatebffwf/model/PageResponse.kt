package az.pashabank.dp.ms.investigatebffwf.model

data class PageInfo(
    val totalCount: Int,
    val offset: Int,
    val limit: Int,
    val hasNextPage: Boolean,
)

data class PageResponse<T>(
    val items: List<T>,
    val pageInfo: PageInfo,
)
