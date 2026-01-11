import os
import structlog

fn main() {
	// Initialize logger with edited timestamp.
	log := structlog.new(
		timestamp: structlog.Timestamp{
			format: .unix
		}
		handler:   structlog.JSONHandler{
			writer: os.stdout()
		}
	)
	defer {
		log.close()
	}

	log.info().message('Hello, World!').send()
}
