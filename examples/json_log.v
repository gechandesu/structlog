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
	log.info().add('random_string', rand.string(100)).send()
	log.info().add('answer', 42).add('computed_by', 'Deep Thought').send()
	log.error().message('this line contains error').error(error('oops')).send()
}
