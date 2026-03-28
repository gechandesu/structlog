import os
import structlog

fn main() {
	// Open a file in append mode. If file does not exists it will be created.
	log_path := os.join_path_single(os.temp_dir(), 'example_log')
	log_file := os.open_file(log_path, 'a+') or {
		eprintln('Error: cound not open log file ${log_path}: ${err}')
		exit(1)
	}

	eprintln('Log file location: ${log_path}')

	// Initialize logger with os.File as writer.
	log := structlog.new(
		handler: structlog.TextHandler{
			color:  false
			writer: log_file
		}
	)
	defer {
		log.close()
	}

	log.info().message('Hello, World!').send()
}
