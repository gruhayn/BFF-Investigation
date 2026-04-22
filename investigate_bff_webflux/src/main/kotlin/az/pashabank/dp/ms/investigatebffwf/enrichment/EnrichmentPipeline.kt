package az.pashabank.dp.ms.investigatebffwf.enrichment

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import reactor.core.publisher.Flux
import reactor.core.publisher.Mono

@Component
class EnrichmentPipeline {

    private val log = LoggerFactory.getLogger(EnrichmentPipeline::class.java)

    fun <T> run(items: List<T>, enrichers: List<Enricher<T>>, includes: Set<String>): Mono<Void> {
        log.info("ActionLog.enrichmentPipeline.start includes={}", includes)

        // Phase 1: independent enrichers run concurrently
        val phase1 = enrichers.filter { includes.contains(it.key()) && it.dependsOn() == null }
        val phase1Mono = if (phase1.isEmpty()) {
            Mono.empty()
        } else {
            Flux.merge(phase1.map { Mono.fromRunnable<Void> { it.enrich(items) } }).then()
        }

        // Phase 2: dependent enrichers run after phase 1
        return phase1Mono.then(
            Mono.fromRunnable<Void> {
                val phase2 = enrichers.filter { e ->
                    includes.contains(e.key()) && e.dependsOn() != null && includes.contains(e.dependsOn())
                }
                phase2.forEach { it.enrich(items) }
                log.info("ActionLog.enrichmentPipeline.end")
            }
        )
    }
}
