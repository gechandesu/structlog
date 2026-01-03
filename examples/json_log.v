import os
import rand
import structlog

fn main() {
	// Initialize logger with JSONHandler.
	log := structlog.new(
		level:   .trace
		handler: structlog.JSONHandler{
			writer: os.stdout()
		}
	)
	defer {
		log.close()
	}

	log.info().message('Hello, World!').send()
	log.info().field('random_string', rand.string(5)).send()
	log.info().field('answer', 42).field('computed_by', 'Deep Thought').send()
	log.error().message('this line contains error').error(error('oops')).send()
}
