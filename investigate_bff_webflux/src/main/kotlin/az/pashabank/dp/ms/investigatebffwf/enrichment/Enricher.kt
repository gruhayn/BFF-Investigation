package az.pashabank.dp.ms.investigatebffwf.enrichment

interface Enricher<T> {
    fun key(): String
    fun dependsOn(): String? = null
    fun enrich(items: List<T>)
}
