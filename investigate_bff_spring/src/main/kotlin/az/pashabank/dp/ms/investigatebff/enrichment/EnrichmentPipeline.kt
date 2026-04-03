package az.pashabank.dp.ms.investigatebff.enrichment

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import java.util.concurrent.CompletableFuture

@Component
class EnrichmentPipeline {

    private val log = LoggerFactory.getLogger(EnrichmentPipeline::class.java)

    fun <T> run(items: List<T>, enrichers: List<Enricher<T>>, includes: Set<String>) {
        log.info("ActionLog.enrichmentPipeline.start includes={}", includes)

        // Phase 1: run enrichers with no dependencies concurrently
        val phase1 = enrichers.filter { includes.contains(it.key()) && it.dependsOn() == null }
        val futures1 = phase1.map { enricher ->
            CompletableFuture.runAsync { enricher.enrich(items) }
        }
        CompletableFuture.allOf(*futures1.toTypedArray()).join()

        // Phase 2: run enrichers that depend on phase 1 results
        val phase2 = enrichers.filter { e ->
            includes.contains(e.key()) && e.dependsOn() != null && includes.contains(e.dependsOn())
        }
        val futures2 = phase2.map { enricher ->
            CompletableFuture.runAsync { enricher.enrich(items) }
        }
        CompletableFuture.allOf(*futures2.toTypedArray()).join()

        log.info("ActionLog.enrichmentPipeline.end")
    }
}
