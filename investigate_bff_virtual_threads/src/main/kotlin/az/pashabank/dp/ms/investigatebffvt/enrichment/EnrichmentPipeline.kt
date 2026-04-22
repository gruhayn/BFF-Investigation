package az.pashabank.dp.ms.investigatebffvt.enrichment

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors

@Component
class EnrichmentPipeline {

    private val log = LoggerFactory.getLogger(EnrichmentPipeline::class.java)
    private val virtualThreadExecutor = Executors.newVirtualThreadPerTaskExecutor()

    fun <T> run(items: List<T>, enrichers: List<Enricher<T>>, includes: Set<String>) {
        log.info("ActionLog.enrichmentPipeline.start includes={}", includes)

        // Phase 1: independent enrichers run concurrently on virtual threads
        val phase1 = enrichers.filter { includes.contains(it.key()) && it.dependsOn() == null }
        val futures1 = phase1.map { enricher ->
            CompletableFuture.runAsync({ enricher.enrich(items) }, virtualThreadExecutor)
        }
        CompletableFuture.allOf(*futures1.toTypedArray()).join()

        // Phase 2: dependent enrichers run concurrently on virtual threads after phase 1
        val phase2 = enrichers.filter { e ->
            includes.contains(e.key()) && e.dependsOn() != null && includes.contains(e.dependsOn())
        }
        val futures2 = phase2.map { enricher ->
            CompletableFuture.runAsync({ enricher.enrich(items) }, virtualThreadExecutor)
        }
        CompletableFuture.allOf(*futures2.toTypedArray()).join()

        log.info("ActionLog.enrichmentPipeline.end")
    }
}
