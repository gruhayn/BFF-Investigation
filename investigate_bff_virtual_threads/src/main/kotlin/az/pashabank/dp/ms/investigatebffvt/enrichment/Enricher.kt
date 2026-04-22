package az.pashabank.dp.ms.investigatebffvt.enrichment

interface Enricher<T> {
    fun key(): String
    fun dependsOn(): String? = null
    fun enrich(items: List<T>)
}
