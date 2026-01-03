import rand
import structlog

fn main() {
	// Initialize logger with default configuratuion.
	log := structlog.new()
	defer {
		// Since processing and writing the log is done in a separate thread,
		// we need to wait for it to complete before exiting the program.
		log.close()
	}

	// Write some logs.
	//
	// Note the call chain. First, the info() call creates a empty `structlog.Record`
	// object with `info` log level. The next message() call adds a message field with
	// the specified text to the record. The final send() call sends the record to the
	// record handler (TextHandler by default) which writes log to stardard output.
	log.info().message('Hello, World!').send()

	// You can set your own named fields.
	log.info().field('random_string', rand.string(5)).send()
	log.info().field('answer', 42).field('computed_by', 'Deep Thought').send()

	// Errors can be passed to logger as is.
	log.error().message('this line contains error').error(error('oops')).send()
}
