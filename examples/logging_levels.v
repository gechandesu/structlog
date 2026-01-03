import structlog

fn main() {
	// Initialize logger with non-default logging level.
	log := structlog.new(level: .trace) // try to change logging level
	defer {
		log.close()
	}

	log.trace().message('hello trace').send()
	log.debug().message('hello debug').send()
	log.info().message('hello info').send()
	log.warn().message('hello warn').send()
	log.error().message('hello error').send()
	log.fatal().message('hello fatal').send() // on fatal program exits immediately with exit code 1
}
