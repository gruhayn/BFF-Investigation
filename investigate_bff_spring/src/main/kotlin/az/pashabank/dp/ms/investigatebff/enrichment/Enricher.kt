package az.pashabank.dp.ms.investigatebff.enrichment

interface Enricher<T> {
    fun key(): String
    fun dependsOn(): String? = null
    fun enrich(items: List<T>)
}
